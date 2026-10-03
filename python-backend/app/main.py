from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.routes.user_router import router as user_router
from app.routes.recommend_router import router as recommend_router
from app.routes.news_router import router as news_router
from app.config.db import connect_to_mongo, close_mongo_connection
import logging
import sys

# Debug prints contain emoji; Windows consoles default to cp1252 and would crash on them.
for _stream in (sys.stdout, sys.stderr):
    if hasattr(_stream, "reconfigure"):
        _stream.reconfigure(encoding="utf-8", errors="replace")

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler("app.log")
    ]
)

app = FastAPI()

# CORS Configuration (Simplified)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all origins
    allow_credentials=True,
    allow_methods=["*"],  # Allow all methods
    allow_headers=["*"],  # Allow all headers
)

@app.on_event("startup")
async def startup():
    await connect_to_mongo()

@app.on_event("shutdown")
async def shutdown():
    await close_mongo_connection()

app.include_router(user_router)
app.include_router(recommend_router)
app.include_router(news_router)