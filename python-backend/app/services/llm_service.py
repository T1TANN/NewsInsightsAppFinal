# app/services/llm_service.py
import json
import logging
import os

import requests
from dotenv import load_dotenv

load_dotenv()
logger = logging.getLogger(__name__)

GROQ_URL = "https://api.groq.com/openai/v1/chat/completions"


class LLMError(Exception):
    pass


class LLMService:
    """Thin client for Groq's OpenAI-compatible chat API, with a fallback model."""

    def __init__(self):
        self.api_key = os.getenv("GROQ_API_KEY")
        self.models = [m for m in (os.getenv("GROQ_MODEL", "openai/gpt-oss-120b"),
                                   os.getenv("GROQ_FALLBACK_MODEL", "qwen/qwen3.8-27b")) if m]
        if not self.api_key:
            logger.warning("GROQ_API_KEY is not set; LLM features will be unavailable")

    @property
    def available(self) -> bool:
        return bool(self.api_key)

    def chat_json(self, system: str, user: str, max_tokens: int = 1200, temperature: float = 0.2) -> dict:
        """Run a chat completion that must return a JSON object. Tries each model in order."""
        if not self.available:
            raise LLMError("GROQ_API_KEY is not configured")

        last_error = None
        for model in self.models:
            payload = {
                "model": model,
                "messages": [{"role": "system", "content": system},
                             {"role": "user", "content": user}],
                "temperature": temperature,
                "max_completion_tokens": max_tokens,
                "response_format": {"type": "json_object"},
            }
            if model.startswith("openai/gpt-oss"):
                payload["reasoning_effort"] = "low"
            try:
                resp = requests.post(
                    GROQ_URL,
                    headers={"Authorization": f"Bearer {self.api_key}"},
                    json=payload,
                    timeout=45,
                )
                if resp.status_code != 200:
                    raise LLMError(f"{model} returned HTTP {resp.status_code}: {resp.text[:200]}")
                content = resp.json()["choices"][0]["message"]["content"]
                return json.loads(content)
            except (requests.RequestException, LLMError, KeyError, ValueError) as e:
                last_error = e
                logger.warning(f"LLM call failed on {model}: {e}")
        raise LLMError(f"All LLM models failed: {last_error}")


llm = LLMService()
