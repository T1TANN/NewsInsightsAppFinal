# app/services/article_extractor.py
import html
import json
import logging
import re
from html.parser import HTMLParser

import requests

logger = logging.getLogger(__name__)

_HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
                  "(KHTML, like Gecko) Chrome/126.0 Safari/537.36",
    "Accept-Language": "en-US,en;q=0.9",
}
_SKIP_TAGS = {"script", "style", "noscript", "nav", "footer", "header", "aside", "form", "figure"}


class _TextBlocks(HTMLParser):
    """Collects text from <p> tags and article-body divs, skipping page chrome."""

    def __init__(self):
        super().__init__()
        self.blocks = []
        self._skip = 0
        self._in_p = 0
        self._buf = []

    def handle_starttag(self, tag, attrs):
        if tag in _SKIP_TAGS:
            self._skip += 1
        elif tag == "p":
            self._in_p += 1
        elif tag == "br" and self._in_p:
            self._buf.append(" ")

    def handle_endtag(self, tag):
        if tag in _SKIP_TAGS and self._skip:
            self._skip -= 1
        elif tag == "p" and self._in_p:
            self._in_p -= 1
            text = " ".join("".join(self._buf).split())
            if len(text) > 60:
                self.blocks.append(text)
            self._buf = []

    def handle_data(self, data):
        if self._in_p and not self._skip:
            self._buf.append(data)


_LD_JSON = re.compile(r'<script[^>]*application/ld\+json[^>]*>(.*?)</script>', re.S | re.I)


def _find_article_body(node):
    """Walk a JSON-LD structure and return the longest articleBody string."""
    best = ""
    if isinstance(node, dict):
        body = node.get("articleBody")
        if isinstance(body, str) and len(body) > len(best):
            best = body
        for v in node.values():
            found = _find_article_body(v)
            if len(found) > len(best):
                best = found
    elif isinstance(node, list):
        for v in node:
            found = _find_article_body(v)
            if len(found) > len(best):
                best = found
    return best


def _json_ld_body(page: str) -> str:
    """Many news sites (e.g. Times of India) ship the full text as schema.org JSON-LD."""
    best = ""
    for block in _LD_JSON.findall(page):
        try:
            data = json.loads(block.strip(), strict=False)
        except ValueError:
            continue
        body = _find_article_body(data)
        if len(body) > len(best):
            best = body
    return html.unescape(re.sub(r"<[^>]+>", " ", best)).strip()


def extract_article_text(url: str, max_chars: int = 20000) -> str:
    """Best-effort download of an article's main text. Returns '' on failure."""
    if not url or not url.startswith("http"):
        return ""
    try:
        resp = requests.get(url, headers=_HEADERS, timeout=12)
        if resp.status_code != 200 or "html" not in resp.headers.get("content-type", ""):
            return ""
        structured = _json_ld_body(resp.text)
        parser = _TextBlocks()
        parser.feed(resp.text)
        paragraphs = "\n\n".join(parser.blocks)
        text = structured if len(structured) >= len(paragraphs) * 0.8 else paragraphs
        return text[:max_chars]
    except Exception as e:
        logger.warning(f"Article extraction failed for {url}: {e}")
        return ""
