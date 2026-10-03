# app/services/summarize_service.py
import logging
import re
import unicodedata

from fastapi import HTTPException

from app.services.article_extractor import extract_article_text
from app.services.llm_service import llm, LLMError

logger = logging.getLogger(__name__)

MIN_WORDS = 25
SINGLE_PASS_CHARS = 40000   # ~10k tokens; well inside the model's context window
CHUNK_CHARS = 15000

SYSTEM_PROMPT = """You are a careful news editor. Summarize the text you are given.
Rules:
- Use ONLY facts stated in the text. Never add outside knowledge, guesses or opinions.
- Keep names, numbers, dates, currencies and places exactly as written.
- The text may come from OCR and contain broken words or typos; silently correct only obvious errors.
- Ignore boilerplate such as ads, navigation, "Also Read" links and subscription prompts.
- Write in clear, neutral English.
Return a JSON object with exactly these keys:
  "title": a short headline (max 12 words),
  "summary": one paragraph of 2-4 sentences covering who, what, when, where and why,
  "key_points": an array of 3-5 short bullet strings with the most important facts."""

NOTES_PROMPT = """You condense one section of a longer news text into factual notes.
Use only facts from the text, keep names and numbers exact.
Return JSON: {"notes": [array of short factual bullet strings]}"""


def clean_text(text: str) -> str:
    """Light normalisation that keeps meaning intact (unlike stripping punctuation or short words)."""
    text = unicodedata.normalize("NFKC", text)
    text = re.sub(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]", "", text)   # control chars
    text = re.sub(r"(\w)-\s*\n\s*(\w)", r"\1\2", text)              # "con-\nnection" -> "connection"
    text = re.sub(r"\[\+\d+ chars\]", "", text)                      # NewsAPI truncation marker
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\s*\n\s*", "\n", text)
    return text.strip()


def _chunks(text: str, size: int):
    paragraphs, buf = text.split("\n"), ""
    for p in paragraphs:
        if len(buf) + len(p) > size and buf:
            yield buf
            buf = ""
        buf += p + "\n"
    if buf.strip():
        yield buf


def _summarize_text(text: str) -> dict:
    if len(text) > SINGLE_PASS_CHARS:
        # Map-reduce: condense each section into notes, then summarise the notes.
        notes = []
        for part in _chunks(text, CHUNK_CHARS):
            notes.extend(llm.chat_json(NOTES_PROMPT, part, max_tokens=800).get("notes", []))
        text = "\n".join(f"- {n}" for n in notes)

    result = llm.chat_json(SYSTEM_PROMPT, f"TEXT:\n{text}")
    summary = str(result.get("summary", "")).strip()
    if not summary:
        raise LLMError("Model returned an empty summary")
    points = [str(p).strip() for p in result.get("key_points", []) if str(p).strip()][:5]
    return {"title": str(result.get("title", "")).strip(), "summary_text": summary, "key_points": points}


def summarize(text: str = "", url: str = "", title: str = "", description: str = "", content: str = "") -> dict:
    """Summarise raw text, or an article by URL (falling back to its NewsAPI snippet)."""
    source = "text"
    body = clean_text(text or "")

    if not body and url:
        body = clean_text(extract_article_text(url))
        source = "article"
        if len(body.split()) < 80:
            snippet = "\n".join(x for x in (title, description, content) if x)
            body = clean_text(snippet)
            source = "snippet"

    if len(body.split()) < MIN_WORDS and source != "snippet":
        raise HTTPException(status_code=400, detail="Text is too short to summarize (need at least 25 words).")
    if not body:
        raise HTTPException(status_code=400, detail="Nothing to summarize.")

    try:
        result = _summarize_text(body)
    except LLMError as e:
        logger.error(f"Summarization failed: {e}")
        raise HTTPException(status_code=502, detail="The AI summarizer is unavailable right now. Please try again.")

    return {"status": True, "source": source, "result": result}
