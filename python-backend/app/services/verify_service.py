# app/services/verify_service.py
"""Fake news classification service.

Powered by a trained PassiveAggressiveClassifier model and TF-IDF Vectorizer
trained on the Indian News Dataset (2 Lakh records), augmented with linguistic
feature analysis and archive corroboration.
"""
import logging
import math
import os
import pickle
import re
from typing import Dict, List, Optional
from urllib.parse import urlparse

from fastapi import HTTPException
from app.services.article_extractor import extract_article_text
from app.services.news_service import news_service
from app.services.summarize_service import clean_text

logger = logging.getLogger(__name__)

VERDICTS = {
    "likely_real": "Likely Real",
    "unverified": "Unverified",
    "misleading": "Possibly Misleading",
    "likely_fake": "Likely Fake",
}

# Known reputable news sources
TRUSTED_SOURCES = {
    "the hindu", "hindustan times", "business standard", "indian express",
    "ndtv", "times of india", "reuters", "press trust of india", "pti",
    "ani", "bbc", "the economic times", "livemint", "dd news", "all india radio"
}


class ModelLoader:
    """Safely loads and caches the scikit-learn model and TF-IDF vectorizer."""

    _instance = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(ModelLoader, cls).__new__(cls)
            cls._instance._load()
        return cls._instance

    def _load(self):
        current_dir = os.path.dirname(os.path.abspath(__file__))
        backend_dir = os.path.dirname(os.path.dirname(current_dir))
        workspace_dir = os.path.dirname(backend_dir)

        # Look in workspace root then backend root
        model_paths = [
            os.path.join(workspace_dir, "fake_news_classifier_model.pkl"),
            os.path.join(backend_dir, "fake_news_classifier_model.pkl"),
        ]
        vec_paths = [
            os.path.join(workspace_dir, "tfidf_vectorizer.pkl"),
            os.path.join(backend_dir, "tfidf_vectorizer.pkl"),
        ]

        self.model = None
        self.vectorizer = None
        self.vocabulary_rev = {}

        for p in model_paths:
            if os.path.exists(p):
                try:
                    with open(p, "rb") as f:
                        self.model = pickle.load(f)
                    logger.info(f"Loaded fake news model from {p}")
                    break
                except Exception as e:
                    logger.error(f"Error loading model from {p}: {e}")

        for p in vec_paths:
            if os.path.exists(p):
                try:
                    with open(p, "rb") as f:
                        self.vectorizer = pickle.load(f)
                    self.vocabulary_rev = {v: k for k, v in self.vectorizer.vocabulary_.items()}
                    logger.info(f"Loaded TF-IDF vectorizer from {p}")
                    break
                except Exception as e:
                    logger.error(f"Error loading vectorizer from {p}: {e}")

        if not self.model or not self.vectorizer:
            logger.warning("Classifier or vectorizer could not be loaded!")


_loader = ModelLoader()


def _domain(url: str) -> str:
    host = urlparse(url or "").netloc.lower()
    return host[4:] if host.startswith("www.") else host


def _extract_claims(text: str) -> List[str]:
    """Extracts 2-4 candidate factual statements from the body."""
    sentences = [s.strip() for s in re.split(r"(?<=[.!?])\s+", text) if len(s.strip()) > 20]
    return sentences[:4] if sentences else [text[:150]]


def verify(
    text: str = "",
    url: str = "",
    title: str = "",
    description: str = "",
    source: str = ""
) -> dict:
    """Performs fake news classification using the PassiveAggressive ML model & TF-IDF vectorizer."""
    body = clean_text(text or "")
    if not body and url:
        body = clean_text(extract_article_text(url))
        if len(body.split()) < 30:
            body = clean_text("\n".join(x for x in (title, description) if x))

    if title and title not in body[:300]:
        body = f"{title}\n\n{body}".strip()

    if len(body.split()) < 5:
        raise HTTPException(
            status_code=400,
            detail="Not enough text to analyze. Please provide at least a sentence or headline."
        )

    clean_source = (source or _domain(url) or "User Submission").strip()
    full_input = f"{title} {description} {body}".strip()

    # Model inference
    model = _loader.model
    vec = _loader.vectorizer

    if not model or not vec:
        raise HTTPException(
            status_code=500,
            detail="Fake news ML classifier model is not loaded."
        )

    X = vec.transform([full_input])
    raw_pred = int(model.predict(X)[0])  # 0 = Real, 1 = Fake
    decision_val = float(model.decision_function(X)[0])  # > 0 => Fake, < 0 => Real

    # Sigmoid mapping from decision value to credibility probability
    # When decision_val is negative (Real), prob_fake is low => credibility is high
    prob_fake = 1.0 / (1.0 + math.exp(-decision_val))
    credibility_score = int(round((1.0 - prob_fake) * 100))

    # Linguistic analysis
    signals = []
    
    # 1. Active TF-IDF features that influenced the model
    coefs = model.coef_[0]
    cx = X.tocoo()
    fake_indicators = []
    real_indicators = []

    for col in cx.col:
        word = _loader.vocabulary_rev.get(col, "")
        weight = coefs[col]
        if weight > 0.05:
            fake_indicators.append((word, weight))
        elif weight < -0.05:
            real_indicators.append((word, weight))

    fake_indicators.sort(key=lambda x: x[1], reverse=True)
    real_indicators.sort(key=lambda x: x[1])

    if raw_pred == 1:
        # Fake classification
        top_terms = [w for w, _ in fake_indicators[:4]]
        if top_terms:
            signals.append({
                "label": "Suspicious Vocabulary",
                "detail": f"Model detected terms correlated with fabricated news: {', '.join(top_terms)}.",
                "impact": "negative"
            })
        signals.append({
            "label": "ML Classification",
            "detail": f"Passive-Aggressive Classifier flagged content as Likely Fake (decision margin: {decision_val:.2f}).",
            "impact": "negative"
        })
    else:
        # Real classification
        top_terms = [w for w, _ in real_indicators[:4]]
        if top_terms:
            signals.append({
                "label": "Journalistic Phrasing",
                "detail": f"Model identified standard reporting vocabulary: {', '.join(top_terms)}.",
                "impact": "positive"
            })
        signals.append({
            "label": "ML Classification",
            "detail": f"Passive-Aggressive Classifier verified content as Likely Real (decision margin: {decision_val:.2f}).",
            "impact": "positive"
        })

    # 2. Check for sensationalism (all caps, exclamation marks, clickbait)
    exclamations = full_input.count("!")
    caps_words = [w for w in full_input.split() if w.isupper() and len(w) > 2]
    if exclamations >= 2 or len(caps_words) >= 3:
        signals.append({
            "label": "Sensational Formatting",
            "detail": f"Detected high intensity formatting ({exclamations} exclamation marks, {len(caps_words)} ALL-CAPS words).",
            "impact": "negative"
        })
        credibility_score = max(5, credibility_score - 15)

    # 3. Source credibility check
    source_lower = clean_source.lower()
    is_trusted = any(ts in source_lower for ts in TRUSTED_SOURCES)
    if is_trusted:
        signals.append({
            "label": "Established Publisher",
            "detail": f"Article source '{clean_source}' is recognized as an established news outlet.",
            "impact": "positive"
        })
        credibility_score = min(98, credibility_score + 10)
    elif "unverified" in source_lower or "whatsapp" in source_lower or "social" in source_lower:
        signals.append({
            "label": "Unverified Origin",
            "detail": "Content originates from an unverified source or social circulation.",
            "impact": "negative"
        })
        credibility_score = max(5, credibility_score - 10)

    # Corroboration search in the 2 Lakh dataset
    # Extract search query from title or first few key words
    search_words = [w for w in re.sub(r"[^\w\s]", "", title or body).split() if len(w) > 3][:4]
    search_query = " ".join(search_words)
    coverage = []
    has_archive_corroboration = False

    if search_query:
        try:
            matches = news_service.search(search_query, page_size=4)
            for m in matches:
                # If matched news is from a real outlet (label == 0)
                is_real_match = (m.get("label") == 0)
                if is_real_match:
                    has_archive_corroboration = True
                coverage.append({
                    "title": m.get("title", ""),
                    "source": (m.get("source") or {}).get("name", "Archive Record"),
                    "url": m.get("url", ""),
                    "publishedAt": m.get("publishedAt", ""),
                    "supports": is_real_match
                })
        except Exception as e:
            logger.warning(f"Archive search failed: {e}")

    if has_archive_corroboration:
        signals.append({
            "label": "Archive Corroboration",
            "detail": "Found matching topic reports from verified outlets in the 200,000 Indian News archive.",
            "impact": "positive"
        })
        if raw_pred == 0:
            credibility_score = max(credibility_score, 75)
    elif raw_pred == 1 and not coverage:
        signals.append({
            "label": "Lack of Mainstream Coverage",
            "detail": "No corroborating reports found across national news databases.",
            "impact": "negative"
        })
        credibility_score = min(credibility_score, 30)

    # Final verdict assignment
    if credibility_score >= 65:
        verdict = "likely_real"
        confidence = "high" if abs(decision_val) > 0.8 else "medium"
        summary = (
            f"This content is classified as Likely Real with a credibility score of {credibility_score}/100. "
            f"The ML model found standard journalistic language patterns consistent with verified reporting."
        )
    elif credibility_score <= 40:
        verdict = "likely_fake"
        confidence = "high" if abs(decision_val) > 0.8 else "medium"
        summary = (
            f"This content is classified as Likely Fake with a credibility score of {credibility_score}/100. "
            f"The ML model identified language and vocabulary patterns commonly found in unverified viral claims."
        )
    else:
        verdict = "misleading" if exclamations > 1 else "unverified"
        confidence = "medium"
        summary = (
            f"This content received a borderline credibility score of {credibility_score}/100. "
            f"Evidence is mixed or insufficient to confirm full authenticity; treat with caution."
        )

    # Claims assessment
    candidate_claims = _extract_claims(body)
    claims = []
    for c in candidate_claims:
        if verdict == "likely_fake":
            status = "unsupported"
            note = "Correlated with unverified phrasing in classifier training data."
        elif verdict == "likely_real":
            status = "supported" if has_archive_corroboration else "unverifiable"
            note = "Consistent with verified news style."
        else:
            status = "unverifiable"
            note = "Requires independent official confirmation."

        claims.append({
            "claim": c,
            "status": status,
            "note": note
        })

    return {
        "status": True,
        "verdict": verdict,
        "label": VERDICTS[verdict],
        "credibility_score": credibility_score,
        "confidence": confidence,
        "summary": summary,
        "signals": signals[:6],
        "claims": claims[:4],
        "coverage": coverage,
        "query": search_query,
        "model_info": {
            "model": "PassiveAggressiveClassifier",
            "vectorizer": "TF-IDF (1.6.1)",
            "dataset": "Indian News 2 Lakh Dataset",
            "decision_score": round(decision_val, 4)
        }
    }
