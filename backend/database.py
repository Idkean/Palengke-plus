import os
import sqlite3
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
DB_PATH = str(BASE_DIR / "calamba_prices.db")

DATABASE_URL = (os.getenv("DATABASE_URL") or os.getenv("POSTGRES_URL") or "").strip()
# Render gives postgres:// ; psycopg wants postgresql://
if DATABASE_URL.startswith("postgres://"):
    DATABASE_URL = DATABASE_URL.replace("postgres://", "postgresql://", 1)
USE_POSTGRES = bool(DATABASE_URL)


def get_conn():
    """Returns DB-API connection. Postgres when DATABASE_URL set, else SQLite fallback."""
    if USE_POSTGRES:
        import psycopg  # psycopg[binary] >=3.1
        return psycopg.connect(DATABASE_URL)
    conn = sqlite3.connect(DB_PATH, check_same_thread=False)
    return conn


def _adapt(sql: str) -> str:
    return sql.replace("?", "%s") if USE_POSTGRES else sql


def init_db():
    """Creates store for verified published price observations. Postgres or SQLite."""
    conn = get_conn()
    try:
        cur = conn.cursor()
        if USE_POSTGRES:
            cur.execute("""
                CREATE TABLE IF NOT EXISTS prices (
                    id SERIAL PRIMARY KEY,
                    date TEXT NOT NULL,
                    commodity TEXT NOT NULL,
                    category TEXT NOT NULL,
                    price DOUBLE PRECISION NOT NULL,
                    unit TEXT DEFAULT 'per kg',
                    source TEXT NOT NULL,
                    source_url TEXT NOT NULL,
                    coverage TEXT NOT NULL,
                    UNIQUE(date, commodity)
                )
            """)
            cur.execute("""
                CREATE TABLE IF NOT EXISTS vendor_prices (
                    id SERIAL PRIMARY KEY,
                    date TEXT NOT NULL,
                    commodity TEXT NOT NULL,
                    price DOUBLE PRECISION NOT NULL,
                    unit TEXT NOT NULL,
                    vendor_name TEXT NOT NULL,
                    market TEXT NOT NULL,
                    notes TEXT DEFAULT ''
                )
            """)
            cur.execute("""
                CREATE TABLE IF NOT EXISTS vendor_users (
                    id SERIAL PRIMARY KEY,
                    username TEXT UNIQUE NOT NULL,
                    password_hash TEXT NOT NULL,
                    market TEXT NOT NULL,
                    created_at TEXT NOT NULL
                )
            """)
            # backfill columns if upgrading from older schema
            cur.execute("SELECT column_name FROM information_schema.columns WHERE table_name='prices'")
            cols = {r[0] for r in cur.fetchall()}
            if "source_url" not in cols:
                cur.execute("ALTER TABLE prices ADD COLUMN IF NOT EXISTS source_url TEXT NOT NULL DEFAULT ''")
            if "coverage" not in cols:
                cur.execute("ALTER TABLE prices ADD COLUMN IF NOT EXISTS coverage TEXT NOT NULL DEFAULT 'Unknown'")
        else:
            cur.execute("""
                CREATE TABLE IF NOT EXISTS prices (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    date TEXT NOT NULL,
                    commodity TEXT NOT NULL,
                    category TEXT NOT NULL,
                    price REAL NOT NULL,
                    unit TEXT DEFAULT 'per kg',
                    source TEXT NOT NULL,
                    source_url TEXT NOT NULL,
                    coverage TEXT NOT NULL,
                    UNIQUE(date, commodity)
                )
            """)
            cur.execute("""
                CREATE TABLE IF NOT EXISTS vendor_prices (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    date TEXT NOT NULL,
                    commodity TEXT NOT NULL,
                    price REAL NOT NULL,
                    unit TEXT NOT NULL,
                    vendor_name TEXT NOT NULL,
                    market TEXT NOT NULL,
                    notes TEXT DEFAULT ''
                )
            """)
            cur.execute("""
                CREATE TABLE IF NOT EXISTS vendor_users (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    username TEXT UNIQUE NOT NULL,
                    password_hash TEXT NOT NULL,
                    market TEXT NOT NULL,
                    created_at TEXT NOT NULL
                )
            """)
            columns = {row[1] for row in cur.execute("PRAGMA table_info(prices)")}
            if "source_url" not in columns:
                cur.execute("ALTER TABLE prices ADD COLUMN source_url TEXT NOT NULL DEFAULT ''")
            if "coverage" not in columns:
                cur.execute("ALTER TABLE prices ADD COLUMN coverage TEXT NOT NULL DEFAULT 'Unknown'")
        conn.commit()
    finally:
        conn.close()


def reset_db():
    init_db()
    conn = get_conn()
    try:
        cur = conn.cursor()
        cur.execute(_adapt("DELETE FROM prices"))
        conn.commit()
    finally:
        conn.close()


def insert_price(
    record_date: str,
    commodity: str,
    price: float,
    category: str,
    unit: str,
    source: str,
    source_url: str,
    coverage: str,
):
    conn = get_conn()
    try:
        cur = conn.cursor()
        if USE_POSTGRES:
            cur.execute("""
                INSERT INTO prices (date, commodity, category, price, unit, source, source_url, coverage)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (date, commodity) DO UPDATE
                SET category=EXCLUDED.category, price=EXCLUDED.price, unit=EXCLUDED.unit,
                    source=EXCLUDED.source, source_url=EXCLUDED.source_url, coverage=EXCLUDED.coverage
            """, (record_date, commodity.lower().strip(), category, round(price, 2), unit, source, source_url, coverage))
        else:
            cur.execute("""
                INSERT OR REPLACE INTO prices
                (date, commodity, category, price, unit, source, source_url, coverage)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """, (record_date, commodity.lower().strip(), category, round(price, 2), unit, source, source_url, coverage))
        conn.commit()
    finally:
        conn.close()


if __name__ == "__main__":
    init_db()
    if USE_POSTGRES:
        print(f"Database ready at Postgres {DATABASE_URL[:30]}... Run sync_da_prices.py to import official data.")
    else:
        print(f"Database ready at {DB_PATH}. Run sync_da_prices.py to import official data.")