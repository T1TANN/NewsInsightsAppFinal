# app/services/recommend_service.py
import logging
import re

from nltk.corpus import stopwords
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity

from app.services.llm_service import llm, LLMError
from app.services.news_service import news_service, NewsServiceError

logger = logging.getLogger(__name__)

MAX_INTERESTS = 4
MAX_RESULTS = 20

INTEREST_PROMPT = """You build a reader's news interest profile from articles they liked.
Group the liked headlines into 2-4 distinct interests, most important first.
For each interest give:
  "label": a short human-friendly topic name (2-4 words),
  "query": a NewsAPI search query of 2-4 plain keywords (no quotes, no boolean operators)
           that would find NEW, related articles - not the same story.
Return JSON: {"interests": [{"label": "...", "query": "..."}]}"""


def _norm(title: str) -> str:
    return re.sub(r"[^a-z0-9 ]", "", title.lower()).strip()


class RecommendationService:
    def __init__(self):
        self.stop_words = set(stopwords.words("english"))

    def _keyword_interests(self, liked_articles):
        """Fallback when the LLM is unavailable: first meaningful words of each title."""
        interests = []
        for art in liked_articles[:MAX_INTERESTS]:
            words = re.sub(r"[^\w\s]", " ", art["title"]).split()
            words = [w for w in words if w.lower() not in self.stop_words and len(w) > 2][:3]
            if words:
                interests.append({"label": art.get("category", "general").title(), "query": " ".join(words)})
        return interests

    def _interests(self, liked_articles):
        if llm.available:
            titles = "\n".join(f"- {a['title']} (category: {a.get('category', 'general')})" for a in liked_articles)
            try:
                data = llm.chat_json(INTEREST_PROMPT, f"Liked headlines:\n{titles}", max_tokens=600)
                interests = [
                    {"label": str(i["label"]).strip(), "query": str(i["query"]).strip()}
                    for i in data.get("interests", []) if i.get("label") and i.get("query")
                ]
                if interests:
                    return interests[:MAX_INTERESTS], "llm"
            except (LLMError, KeyError, TypeError) as e:
                logger.warning(f"LLM interest extraction failed, using keywords: {e}")
        return self._keyword_interests(liked_articles), "keywords"

    def get_recommendations(self, liked_articles):
        interests, method = self._interests(liked_articles)
        logger.info(f"Interests ({method}): {interests}")

        liked_norm = {_norm(a["title"]) for a in liked_articles}
        seen, candidates = set(), []
        for interest in interests:
            try:
                results = news_service.search(interest["query"], page_size=20)
            except NewsServiceError as e:
                logger.warning(f"News search failed for '{interest['query']}': {e}")
                continue
            for art in results:
                key = _norm(art["title"])
                if not key or key in liked_norm or key in seen or art["url"] in seen:
                    continue
                seen.update((key, art["url"]))
                candidates.append({**art, "interest": interest["label"]})

        if not candidates:
            return {"interests": [i["label"] for i in interests], "method": method, "articles": []}

        # Score each candidate by its closest liked headline (TF-IDF cosine similarity).
        liked_titles = [a["title"] for a in liked_articles]
        docs = liked_titles + [f"{c['title']} {c['description']}" for c in candidates]
        matrix = TfidfVectorizer(stop_words="english", max_features=5000).fit_transform(docs)
        sims = cosine_similarity(matrix[len(liked_titles):], matrix[:len(liked_titles)])
        for cand, row in zip(candidates, sims):
            best = int(row.argmax())
            cand["score"] = float(row[best])
            cand["reason"] = f"Because you liked “{liked_titles[best]}”" if row[best] > 0.05 \
                else f"Matches your interest in {cand['interest']}"

        # Round-robin across interests so one topic doesn't crowd out the rest.
        by_interest = {}
        for cand in sorted(candidates, key=lambda c: c["score"], reverse=True):
            by_interest.setdefault(cand["interest"], []).append(cand)
        ranked, queues = [], list(by_interest.values())
        while queues and len(ranked) < MAX_RESULTS:
            for q in list(queues):
                if q:
                    ranked.append(q.pop(0))
                if not q:
                    queues.remove(q)
                if len(ranked) >= MAX_RESULTS:
                    break

        for r in ranked:
            r.pop("score", None)
        return {"interests": [i["label"] for i in interests], "method": method, "articles": ranked}
