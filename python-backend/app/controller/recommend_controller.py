from fastapi import HTTPException
from fastapi.concurrency import run_in_threadpool
from typing import List
import logging

logger = logging.getLogger(__name__)

class RecommendController:
    def __init__(self, service):
        self.service = service
        logger.info("RecommendController initialized")

    async def recommend_articles(self, liked_articles: List[dict]):
        try:
            if not liked_articles:
                raise HTTPException(status_code=400, detail="No liked articles provided")
            logger.info(f"Processing {len(liked_articles)} most recent liked articles: {[art['title'] for art in liked_articles]}")
            self._validate_input(liked_articles)
            # The service does blocking network I/O, so keep it off the event loop.
            return await run_in_threadpool(self.service.get_recommendations, liked_articles)
        except HTTPException as e:
            raise
        except Exception as e:
            logger.error(f"Recommendation failed: {str(e)}", exc_info=True)
            raise HTTPException(status_code=500, detail="Failed to generate recommendations")

    def _validate_input(self, liked_articles: List[dict]):
        for art in liked_articles:
            if not isinstance(art, dict):
                raise HTTPException(status_code=400, detail="Invalid article format")
            if "title" not in art or not isinstance(art["title"], str):
                raise HTTPException(status_code=400, detail="Articles must contain 'title' string field")
