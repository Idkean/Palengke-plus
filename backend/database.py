import sqlite3
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
DB_PATH = str(BASE_DIR / "calamba_prices.db")


def init_db():
    """Creates the local store for verified published price observations."""
    conn = sqlite3.connect(DB_PATH)
    conn.execute(
        """
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
        """
    )
    columns = {row[1] for row in conn.execute("PRAGMA table_info(prices)")}
    if "source_url" not in columns:
        conn.execute("ALTER TABLE prices ADD COLUMN source_url TEXT NOT NULL DEFAULT ''")
    if "coverage" not in columns:
        conn.execute("ALTER TABLE prices ADD COLUMN coverage TEXT NOT NULL DEFAULT 'Unknown'")
    conn.commit()
    conn.close()


def reset_db():
    init_db()
    conn = sqlite3.connect(DB_PATH)
    conn.execute("DELETE FROM prices")
    conn.commit()
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
    conn = sqlite3.connect(DB_PATH)
    conn.execute(
        """
        INSERT OR REPLACE INTO prices
        (date, commodity, category, price, unit, source, source_url, coverage)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            record_date,
            commodity.lower().strip(),
            category,
            round(price, 2),
            unit,
            source,
            source_url,
            coverage,
        ),
    )
    conn.commit()
    conn.close()


if __name__ == "__main__":
    init_db()
    print(f"Database ready at {DB_PATH}. Run sync_da_prices.py to import official data.")