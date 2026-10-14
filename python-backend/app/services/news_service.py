# app/services/news_service.py
import hashlib
import logging
import os
import re
import sqlite3
from datetime import datetime, timezone, timedelta
from typing import List, Dict, Optional

logger = logging.getLogger(__name__)

# High-resolution, themed Unsplash images per category for rich visual presentation
CATEGORY_IMAGES = {
    "technology": [
        "https://images.unsplash.com/photo-1518770660439-4636190af475?auto=format&fit=crop&w=800&q=80",
        "https://images.unsplash.com/photo-1451187580459-43490279c0fa?auto=format&fit=crop&w=800&q=80",
        "https://images.unsplash.com/photo-1526374965328-7f61d4dc18c5?auto=format&fit=crop&w=800&q=80",
        "https://images.unsplash.com/photo-1531297484001-80022131f5a1?auto=format&fit=crop&w=800&q=80",
        "https://images.unsplash.com/photo-1504384308090-c894fdcc538d?auto=format&fit=crop&w=800&q=80",
        "https://images.unsplash.com/photo-1519389950473-47ba0277781c?auto=format&fit=crop&w=800&q=80",
    ],
    "business": [
        "https://images.unsplash.com/photo-1611974789855-9c2a0a7236a3?auto=format&fit=crop&w=800&q=80",
        "https://images.unsplash.com/photo-1590283603385-17ffb3a7f29f?auto=format&fit=crop&w=800&q=80",
        "https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?auto=format&fit=crop&w=800&q=80",
        "https://images.unsplash.com/photo-1460925895917-afdab827c52f?auto=format&fit=crop&w=800&q=80",
        "https://images.unsplash.com/photo-1559526324-4b87b5e36e44?auto=format&fit=crop&w=800&q=80",
        "https://images.unsplash.com/photo-1526304640581-d334cdbbf45e?auto=format&fit=crop&w=800&q=80",
    ],
    "politics": [
        "https://images.unsplash.com/photo-1541872703-74c5e44368f9?auto=format&fit=crop&w=800&q=80",
        "https://images.unsplash.com/photo-1540910419892-4a36d2c3266c?auto=format&fit=crop&w=800&q=80",
        "https://images.unsplash.com/photo-1529107386315-e1a2ed48a620?auto=format&fit=crop&w=800&q=80",
        "https://images.unsplash.com/photo-1575320181282-9afab399332c?auto=format&fit=crop&w=800&q=80",
        "https://images.unsplash.com/photo-1569098644584-210bcd375b59?auto=format&fit=crop&w=800&q=80",
    ],
    "sports": [
        "https://images.unsplash.com/photo-1531415074968-036ba1b575da?auto=format&fit=crop&w=800&q=80",
        "https://images.unsplash.com/photo-1508098682722-e99c43a406b2?auto=format&fit=crop&w=800&q=80",
        "https://images.unsplash.com/photo-1461896836934-ffe607ba8211?auto=format&fit=crop&w=800&q=80",
        "https://images.unsplash.com/photo-1574629810360-7efbbe195018?auto=format&fit=crop&w=800&q=80",
        "https://images.unsplash.com/photo-1517649763962-0c623266ddc0?auto=format&fit=crop&w=800&q=80",
    ],
    "entertainment": [
        "https://images.unsplash.com/photo-1514525253161-7a46d19cd819?auto=format&fit=crop&w=800&q=80",
        "https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?auto=format&fit=crop&w=800&q=80",
        "https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?auto=format&fit=crop&w=800&q=80",
        "https://images.unsplash.com/photo-1470225620780-dba8ba36b745?auto=format&fit=crop&w=800&q=80",
        "https://images.unsplash.com/photo-1492684223066-81342ee5ff30?auto=format&fit=crop&w=800&q=80",
    ],
    "national": [
        "https://images.unsplash.com/photo-1524492412937-b28074a5d7da?auto=format&fit=crop&w=800&q=80",
        "https://images.unsplash.com/photo-1532375810709-75b1da00537c?auto=format&fit=crop&w=800&q=80",
        "https://images.unsplash.com/photo-1587474260584-136574528ed5?auto=format&fit=crop&w=800&q=80",
        "https://images.unsplash.com/photo-1599839575945-a9e5af0c3fa5?auto=format&fit=crop&w=800&q=80",
        "https://images.unsplash.com/photo-1506461883276-594a12b11cf3?auto=format&fit=crop&w=800&q=80",
    ],
    "general": [
        "https://images.unsplash.com/photo-1504711434969-e33886168f5c?auto=format&fit=crop&w=800&q=80",
        "https://images.unsplash.com/photo-1495020689067-958852a7765e?auto=format&fit=crop&w=800&q=80",
    ],
}


class NewsServiceError(Exception):
    pass


class NewsService:
    """Provides high-performance news querying from the 2 Lakh Indian News Dataset.

    Replaces external NewsAPI calls with fast, indexed, offline SQLite storage with FTS5 search.
    """

    def __init__(self):
        # Locate database file and fallback CSV
        current_dir = os.path.dirname(os.path.abspath(__file__))
        backend_dir = os.path.dirname(os.path.dirname(current_dir))
        workspace_dir = os.path.dirname(backend_dir)

        self.db_path = os.path.join(backend_dir, "data", "news.db")
        self.csv_path = os.path.join(workspace_dir, "indian_news_2lakh_dataset.csv")

        self._ensure_db()

    def _ensure_db(self):
        """Initializes SQLite database from CSV if missing."""
        if os.path.exists(self.db_path) and os.path.getsize(self.db_path) > 10 * 1024 * 1024:
            return

        os.makedirs(os.path.dirname(self.db_path), exist_ok=True)
        logger.info(f"Building news database from {self.csv_path}...")
        try:
            import pandas as pd
            df = pd.read_csv(self.csv_path)
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            cursor.execute("DROP TABLE IF EXISTS news")
            cursor.execute("DROP TABLE IF EXISTS news_fts")
            cursor.execute("""
                CREATE TABLE news (
                    rowid INTEGER PRIMARY KEY AUTOINCREMENT,
                    news_id TEXT UNIQUE,
                    headline TEXT,
                    text TEXT,
                    category TEXT,
                    label INTEGER,
                    source_or_warning TEXT
                )
            """)
            df.to_sql("news", conn, if_exists="append", index=False, chunksize=20000)
            cursor.execute("CREATE INDEX IF NOT EXISTS idx_category ON news(category)")
            cursor.execute("CREATE INDEX IF NOT EXISTS idx_label ON news(label)")
            cursor.execute("CREATE INDEX IF NOT EXISTS idx_news_id ON news(news_id)")

            cursor.execute("""
                CREATE VIRTUAL TABLE news_fts USING fts5(
                    headline,
                    text,
                    content='news',
                    content_rowid='rowid'
                )
            """)
            cursor.execute("INSERT INTO news_fts(news_fts) VALUES('rebuild')")
            conn.commit()
            conn.close()
            logger.info("News database built successfully.")
        except Exception as e:
            logger.error(f"Failed to initialize news database: {e}")

    def _get_connection(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.db_path, timeout=10)
        conn.row_factory = sqlite3.Row
        return conn

    @staticmethod
    def _get_image(category: str, news_id: str) -> str:
        cat = (category or "general").lower()
        images = CATEGORY_IMAGES.get(cat, CATEGORY_IMAGES["general"])
        # Deterministic index based on news_id hash
        idx = int(hashlib.md5(news_id.encode()).hexdigest(), 16) % len(images)
        return images[idx]

    @staticmethod
    def _format_timestamp(rowid: int) -> str:
        # Generate recent timestamps for realism
        now = datetime.now(timezone.utc)
        minutes_offset = (rowid % 2880)  # within last 2 days
        pub_time = now - timedelta(minutes=minutes_offset)
        return pub_time.strftime("%Y-%m-%dT%H:%M:%SZ")

    def _row_to_article(self, row: sqlite3.Row) -> dict:
        news_id = row["news_id"]
        cat = row["category"] or "General"
        headline = (row["headline"] or "").strip()
        text = (row["text"] or "").strip()
        label = row["label"]
        source = (row["source_or_warning"] or "").strip()

        # Build clean snippet description
        desc = text
        if len(desc) > 220:
            end_idx = desc[:220].rfind(". ")
            desc = desc[:end_idx + 1] if end_idx > 100 else desc[:217] + "..."

        rowid = row["rowid"] if "rowid" in row.keys() else 1
        published_at = self._format_timestamp(rowid)
        image_url = self._get_image(cat, news_id)
        author = source if label == 0 and source != "Unverified Source" else "Staff Reporter"

        return {
            "news_id": news_id,
            "title": headline,
            "description": desc,
            "content": text,
            "url": f"https://newsinsights.local/article/{news_id}",
            "urlToImage": image_url,
            "author": author,
            "source": {"name": source or "Indian News Desk"},
            "publishedAt": published_at,
            "category": cat.lower(),
            "label": label,
        }

    def headlines(self, category: Optional[str] = None, page_size: int = 40, offset: int = 0) -> List[dict]:
        """Returns articles, optionally filtered by category.

        Prefers verified real news first (label=0) for default news feed reading.
        """
        conn = self._get_connection()
        try:
            cursor = conn.cursor()
            if category and category.lower() not in ("all", "top", "general"):
                # Clean category name
                cat_clean = category.strip().title()
                query = """
                    SELECT rowid, news_id, headline, text, category, label, source_or_warning
                    FROM news
                    WHERE category = ?
                    ORDER BY label ASC, rowid DESC
                    LIMIT ? OFFSET ?
                """
                cursor.execute(query, (cat_clean, page_size, offset))
            else:
                query = """
                    SELECT rowid, news_id, headline, text, category, label, source_or_warning
                    FROM news
                    ORDER BY label ASC, rowid DESC
                    LIMIT ? OFFSET ?
                """
                cursor.execute(query, (page_size, offset))

            rows = cursor.fetchall()
            return [self._row_to_article(r) for r in rows]
        except Exception as e:
            logger.error(f"Error fetching headlines: {e}")
            raise NewsServiceError(f"Database query error: {e}")
        finally:
            conn.close()

    def search(self, query: str, page_size: int = 30) -> List[dict]:
        """Searches articles using FTS5 full-text search with fallback to LIKE."""
        if not query or not query.strip():
            return self.headlines(page_size=page_size)

        clean_q = re.sub(r"[^\w\s]", " ", query).strip()
        words = clean_q.split()
        if not words:
            return self.headlines(page_size=page_size)

        conn = self._get_connection()
        try:
            cursor = conn.cursor()
            # Try FTS5 MATCH with OR between keywords
            fts_query = " OR ".join(f'"{w}"' for w in words[:6])
            try:
                sql = """
                    SELECT news.rowid, news.news_id, news.headline, news.text, news.category,
                           news.label, news.source_or_warning, rank
                    FROM news_fts
                    JOIN news ON news.rowid = news_fts.rowid
                    WHERE news_fts MATCH ?
                    ORDER BY rank
                    LIMIT ?
                """
                cursor.execute(sql, (fts_query, page_size))
                rows = cursor.fetchall()
                if rows:
                    return [self._row_to_article(r) for r in rows]
            except sqlite3.OperationalError:
                pass  # Fall back to LIKE

            # Fallback LIKE search
            like_pat = f"%{words[0]}%"
            sql = """
                SELECT rowid, news_id, headline, text, category, label, source_or_warning
                FROM news
                WHERE headline LIKE ? OR text LIKE ?
                ORDER BY label ASC, rowid DESC
                LIMIT ?
            """
            cursor.execute(sql, (like_pat, like_pat, page_size))
            rows = cursor.fetchall()
            return [self._row_to_article(r) for r in rows]
        except Exception as e:
            logger.error(f"Search error for '{query}': {e}")
            raise NewsServiceError(f"Search failed: {e}")
        finally:
            conn.close()

    def get_by_id(self, news_id: str) -> Optional[dict]:
        """Retrieves a single article by its news_id."""
        conn = self._get_connection()
        try:
            cursor = conn.cursor()
            cursor.execute(
                "SELECT rowid, news_id, headline, text, category, label, source_or_warning FROM news WHERE news_id = ?",
                (news_id,)
            )
            row = cursor.fetchone()
            return self._row_to_article(row) if row else None
        finally:
            conn.close()


news_service = NewsService()
