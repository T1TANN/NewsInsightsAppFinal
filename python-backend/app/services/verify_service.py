# app/services/verify_service.py
"""Fake news detection.

Pipeline:
  1. Get the article text (from the URL, or pasted/scanned text).
  2. LLM extracts the key factual claims and a search query.
  3. Search NewsAPI for coverage of the same story by other outlets (corroboration).
  4. LLM weighs the writing style, claims and corroboration and predicts a verdict
     with a credibility score, the signals behind it and a per-claim assessment.
"""
import logging
from datetime import datetime, timezone
from urllib.parse import urlparse

from fastapi import HTTPException

from app.services.article_extractor import extract_article_text
from app.services.llm_service import llm, LLMError
from app.services.news_service import news_service, NewsServiceError
from app.services.summarize_service import clean_text

logger = logging.getLogger(__name__)

MAX_TEXT_CHARS = 12000
MAX_EVIDENCE = 8

VERDICTS = {
    "likely_real": "Likely real",
    "unverified": "Unverified",
    "misleading": "Possibly misleading",
    "likely_fake": "Likely fake",
}

CLAIMS_PROMPT = """You prepare a news article for fact-checking.
Extract the 2-4 most important checkable factual claims (who did what, numbers, dates, events).
Also write a NewsAPI search query of 3-5 plain keywords (names, places, event) that would find
OTHER outlets' reports of the same story. No quotes or boolean operators.
Return JSON: {"claims": ["..."], "query": "..."}"""

VERDICT_PROMPT = """You are a careful fact-checking assistant that predicts whether a news item is real or fake.
You receive the ARTICLE, its key CLAIMS, and REPORTS from other outlets found by a news search
(possibly empty or only loosely related).

Judge using these signals:
- Corroboration: do independent outlets report the same specific facts? Contradictions?
- Specificity: named sources, verifiable details, dates and places vs vague attributions.
- Language: sensational, emotional or clickbait wording, ALL CAPS, urgency, calls to share.
- Plausibility and internal consistency of the claims.
- Source: is the publisher a known news organisation? (Only if the source is given.)

Rules:
- Base the verdict on the evidence given. Your own knowledge may be outdated: never call a
  recent event fake just because you have not heard of it - lack of coverage means "unverified".
- "likely_fake" needs strong evidence: contradicted by reports, fabricated-looking details or
  classic hoax patterns. "misleading" = real events but exaggerated, missing context or a
  headline the body does not support.
- Be calibrated: say "unverified" when the evidence is thin.

Return JSON with exactly these keys:
  "verdict": one of "likely_real", "unverified", "misleading", "likely_fake",
  "credibility_score": integer 0-100 (100 = highly credible),
  "confidence": "low" | "medium" | "high",
  "summary": 2-3 sentences explaining the verdict in plain English,
  "signals": array of 3-6 objects {"label": short name, "detail": one sentence,
             "impact": "positive" | "negative" | "neutral"},
  "claims": array of objects {"claim": the claim, "status": "supported" | "unsupported" |
            "contradicted" | "unverifiable", "note": one short sentence}.
            supported = a REPORT confirms it; contradicted = a REPORT says otherwise;
            unsupported = implausible or no sign of it where coverage would be expected;
            unverifiable = plausible but no report covers it,
  "supporting_reports": array of report numbers (integers) that cover the same story."""


def _domain(url: str) -> str:
    host = urlparse(url or "").netloc.lower()
    return host[4:] if host.startswith("www.") else host


def _find_coverage(query: str, exclude_url: str) -> list:
    """Search for other outlets' reports; relax the query if it is too specific."""
    words = query.split()
    attempts = [words[:5], words[:3], words[:2]]
    exclude = _domain(exclude_url)
    for attempt in attempts:
        if not attempt:
            continue
        try:
            results = news_service.search(" ".join(attempt), page_size=20)
        except NewsServiceError as e:
            logger.warning(f"Coverage search failed: {e}")
            return []
        others = [r for r in results if r["url"] != exclude_url and (_domain(r["url"]) != exclude or not exclude)]
        if others:
            return others[:MAX_EVIDENCE]
    return []


def verify(text: str = "", url: str = "", title: str = "", description: str = "",
           source: str = "") -> dict:
    body = clean_text(text or "")
    if not body and url:
        body = clean_text(extract_article_text(url))
        if len(body.split()) < 60:
            body = clean_text("\n".join(x for x in (title, description) if x))
    if title and title not in body[:300]:
        body = f"{title}\n\n{body}"
    if len(body.split()) < 12:
        raise HTTPException(status_code=400, detail="Not enough text to check. Paste at least a sentence or two.")
    body = body[:MAX_TEXT_CHARS]

    try:
        prep = llm.chat_json(CLAIMS_PROMPT, f"ARTICLE:\n{body}", max_tokens=500)
        claims = [str(c).strip() for c in prep.get("claims", []) if str(c).strip()][:4]
        query = str(prep.get("query") or title or " ".join(body.split()[:6])).strip()

        coverage = _find_coverage(query, url)
        reports = "\n".join(
            f"[{i + 1}] {r['source']['name']} ({r['publishedAt'][:10]}): {r['title']} - {r['description'][:200]}"
            for i, r in enumerate(coverage)
        ) or "(no other reports found)"
        today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
        prompt = (
            f"TODAY: {today}\nSOURCE: {source or _domain(url) or 'unknown (pasted or scanned text)'}\n\n"
            f"ARTICLE:\n{body}\n\nCLAIMS:\n" + "\n".join(f"- {c}" for c in claims) + f"\n\nREPORTS:\n{reports}"
        )
        result = llm.chat_json(VERDICT_PROMPT, prompt, max_tokens=1500)
    except LLMError as e:
        logger.error(f"Verification failed: {e}")
        raise HTTPException(status_code=502, detail="The AI fact-checker is unavailable right now. Please try again.")

    verdict = result.get("verdict") if result.get("verdict") in VERDICTS else "unverified"
    try:
        score = max(0, min(100, int(result.get("credibility_score", 50))))
    except (TypeError, ValueError):
        score = 50
    confidence = result.get("confidence") if result.get("confidence") in ("low", "medium", "high") else "low"

    supporting = set()
    for n in result.get("supporting_reports", []) or []:
        try:
            if 1 <= int(n) <= len(coverage):
                supporting.add(int(n) - 1)
        except (TypeError, ValueError):
            pass

    signals = [
        {"label": str(s.get("label", "")).strip(), "detail": str(s.get("detail", "")).strip(),
         "impact": s.get("impact") if s.get("impact") in ("positive", "negative", "neutral") else "neutral"}
        for s in result.get("signals", []) if isinstance(s, dict) and s.get("label")
    ][:6]
    checked = [
        {"claim": str(c.get("claim", "")).strip(),
         "status": c.get("status") if c.get("status") in ("supported", "unsupported", "contradicted", "unverifiable")
         else "unverifiable",
         "note": str(c.get("note", "")).strip()}
        for c in result.get("claims", []) if isinstance(c, dict) and c.get("claim")
    ][:4]

    return {
        "status": True,
        "verdict": verdict,
        "label": VERDICTS[verdict],
        "credibility_score": score,
        "confidence": confidence,
        "summary": str(result.get("summary", "")).strip(),
        "signals": signals,
        "claims": checked,
        "coverage": [
            {"title": r["title"], "source": r["source"]["name"], "url": r["url"],
             "publishedAt": r["publishedAt"], "supports": i in supporting}
            for i, r in enumerate(coverage)
        ],
        "query": query,
    }
