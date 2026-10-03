# app/services/news_service.py
import logging
import os
import time

import requests
from dotenv import load_dotenv

load_dotenv()
logger = logging.getLogger(__name__)

NEWSAPI_EVERYTHING = "https://newsapi.org/v2/everything"
DEFAULT_SOURCES = "the-times-of-india"
CACHE_TTL_SECONDS = 600  # NewsAPI's free plan allows ~100 requests/day, so cache aggressively


class NewsServiceError(Exception):
    pass


class NewsService:
    """Server-side NewsAPI proxy so the API key never ships to the client."""

    def __init__(self):
        self.api_key = os.getenv("NEWSAPI_KEY")
        self._cache = {}

    def _get(self, params: dict) -> list:
        key = tuple(sorted(params.items()))
        cached = self._cache.get(key)
        if cached and time.time() - cached[0] < CACHE_TTL_SECONDS:
            return cached[1]

        if not self.api_key:
            raise NewsServiceError("NEWSAPI_KEY is not configured")
        try:
            resp = requests.get(NEWSAPI_EVERYTHING, params={**params, "apiKey": self.api_key}, timeout=15)
        except requests.RequestException as e:
            raise NewsServiceError(f"NewsAPI request failed: {e}")
        data = resp.json() if resp.headers.get("content-type", "").startswith("application/json") else {}
        if resp.status_code != 200 or data.get("status") != "ok":
            raise NewsServiceError(data.get("message") or f"NewsAPI returned HTTP {resp.status_code}")

        articles = [self._normalize(a) for a in data.get("articles", [])]
        articles = [a for a in articles if a["title"] and a["title"] != "[Removed]"]
        self._cache[key] = (time.time(), articles)
        return articles

    @staticmethod
    def _normalize(a: dict) -> dict:
        return {
            "title": (a.get("title") or "").strip(),
            "description": (a.get("description") or "").strip(),
            "content": (a.get("content") or "").strip(),
            "url": a.get("url") or "",
            "urlToImage": a.get("urlToImage") or "",
            "author": a.get("author") or "",
            "source": {"name": (a.get("source") or {}).get("name") or "Unknown"},
            "publishedAt": a.get("publishedAt") or "",
        }

    def headlines(self, category: str = None, page_size: int = 40) -> list:
        """Latest Times of India articles, optionally filtered by a category keyword."""
        params = {"sources": DEFAULT_SOURCES, "pageSize": page_size, "sortBy": "publishedAt"}
        if category and category.lower() not in ("all", "top", "general"):
            params["q"] = category
        return self._get(params)

    def search(self, query: str, page_size: int = 30) -> list:
        """Search all English sources."""
        return self._get({"q": query, "language": "en", "pageSize": page_size, "sortBy": "relevancy"})


news_service = NewsService()
