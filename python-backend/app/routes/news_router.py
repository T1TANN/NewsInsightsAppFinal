# app/routes/news_router.py
from typing import Optional

from fastapi import APIRouter, HTTPException
from fastapi.concurrency import run_in_threadpool
from pydantic import BaseModel

from app.services.news_service import news_service, NewsServiceError
from app.services.summarize_service import summarize
from app.services.verify_service import verify

router = APIRouter()


class SummarizeRequest(BaseModel):
    text: Optional[str] = ""
    url: Optional[str] = ""
    title: Optional[str] = ""
    description: Optional[str] = ""
    content: Optional[str] = ""


@router.get("/news")
async def get_news(category: Optional[str] = None, q: Optional[str] = None):
    """Proxy to NewsAPI. `q` searches all sources; `category` filters Times of India headlines."""
    try:
        if q and q.strip():
            articles = await run_in_threadpool(news_service.search, q.strip())
        else:
            articles = await run_in_threadpool(news_service.headlines, category)
    except NewsServiceError as e:
        raise HTTPException(status_code=502, detail=str(e))
    return {"status": True, "articles": articles}


@router.post("/summarize")
async def summarize_endpoint(request: SummarizeRequest):
    """Summarise raw `text` (e.g. from OCR) or an article by `url` using the LLM."""
    return await run_in_threadpool(
        summarize, request.text, request.url, request.title, request.description, request.content
    )


class VerifyRequest(BaseModel):
    text: Optional[str] = ""
    url: Optional[str] = ""
    title: Optional[str] = ""
    description: Optional[str] = ""
    source: Optional[str] = ""


@router.post("/verify")
async def verify_endpoint(request: VerifyRequest):
    """Fake news detection: predicts whether an article or pasted text is real, using the LLM
    plus corroboration from other outlets' coverage."""
    return await run_in_threadpool(
        verify, request.text, request.url, request.title, request.description, request.source
    )


# Backwards-compatible path used by the old Colab/ngrok summarizer.
router.add_api_route("/text-summarizer/summarize/", summarize_endpoint, methods=["POST"])
