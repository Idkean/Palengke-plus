import asyncio
import contextlib
import sqlite3
import logging
import os
from contextlib import asynccontextmanager

import time as _time

import pandas as pd
from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware

from database import DB_PATH, init_db
from forecaster import generate_arima_forecast, get_commodity_series
from sync_da_prices import sync as sync_da_prices
_FORECAST_CACHE: dict[tuple, tuple] = {}  # (commodity,horizon) -> (ts, result)
_FORECAST_TTL = 6 * 60 * 60

logger = logging.getLogger(__name__)
DA_SYNC_INTERVAL_SECONDS = int(os.getenv("DA_SYNC_INTERVAL_SECONDS", str(6 * 60 * 60)))
raw_cors = os.getenv("CORS_ORIGINS", "*")
if raw_cors.strip() == "*":
    cors_origins = ["*"]
else:
    cors_origins = [o.strip() for o in raw_cors.split(",") if o.strip()]
allow_creds = False if cors_origins == ["*"] else True


async def da_sync_loop():
    await asyncio.sleep(90)  # ponytail: let first requests serve before heavy PDF sync
    while True:
        try:
            imported = await asyncio.to_thread(sync_da_prices)
            logger.info("DA background sync imported %s observations", imported)
        except Exception:
            logger.exception("DA background sync failed; keeping the last valid database")
        await asyncio.sleep(DA_SYNC_INTERVAL_SECONDS)


@asynccontextmanager
async def lifespan(app):
    init_db()
    sync_task = asyncio.create_task(da_sync_loop())
    try:
        yield
    finally:
        sync_task.cancel()
        with contextlib.suppress(asyncio.CancelledError):
            await sync_task

app = FastAPI(
    title="Palengke+ API (Calamba City)",
    description="Daily commodity price tracking and ARIMA time-series forecasting for Calamba City, Laguna.",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_credentials=allow_creds,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/api/health")
def health_check():
    """Reports API and local data-store readiness."""
    conn = sqlite3.connect(DB_PATH)
    try:
        row = conn.execute(
            "SELECT COUNT(*), MAX(date) FROM prices"
        ).fetchone()
    finally:
        conn.close()

    record_count, latest_date = row
    return {
        "status": "ok",
        "database": "ready",
        "price_records": record_count,
        "latest_price_date": latest_date,
    }


@app.api_route("/api/admin/sync", methods=["GET", "POST"])
async def trigger_sync():
    """Manually triggers DA sync (real PDFs) and returns new counts. ponytail: ephemeral SQLite — move to Postgres when need persistence."""
    try:
        imported = await asyncio.to_thread(sync_da_prices)
        conn = sqlite3.connect(DB_PATH)
        try:
            row = conn.execute("SELECT COUNT(*), MAX(date) FROM prices").fetchone()
        finally:
            conn.close()
        return {"imported": imported, "price_records": row[0], "latest_price_date": row[1], "source": "DA-4A live PDFs"}
    except Exception as e:
        logger.exception("Manual sync failed")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/commodities")
def list_commodities():
    """Lists commodities with category, latest price, and daily movement."""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute("""
        SELECT current.commodity,
               current.category,
               current.price AS latest_price,
               previous.price AS previous_price,
               current.unit,
               current.source,
               current.source_url,
               current.coverage,
               current.date AS last_updated,
               counts.data_points
        FROM prices current
        LEFT JOIN prices previous ON previous.commodity = current.commodity
            AND previous.date = (
                SELECT MAX(date) FROM prices
                WHERE commodity = current.commodity AND date < current.date
            )
        JOIN (
            SELECT commodity, COUNT(*) AS data_points, MAX(date) AS last_updated
            FROM prices GROUP BY commodity
        ) counts ON counts.commodity = current.commodity
            AND counts.last_updated = current.date
        ORDER BY current.category, current.commodity
    """)
    rows = cursor.fetchall()
    conn.close()

    return {
        "commodities": [
            {
                "name": row[0],
                "category": row[1],
                "latest_price": row[2],
                "previous_price": row[3],
                "delta_percent": round(((row[2] - row[3]) / row[3]) * 100, 2) if row[3] else 0,
                "unit": row[4],
                "source": row[5],
                "source_url": row[6],
                "coverage": row[7],
                "last_updated": row[8],
                "data_points": row[9],
            }
            for row in rows
        ]
    }


@app.get("/api/analytics")
def get_analytics():
    """Returns price movement summaries for the analytics dashboard."""
    commodities = list_commodities()["commodities"]
    rising = [item for item in commodities if item["delta_percent"] > 0]
    falling = [item for item in commodities if item["delta_percent"] < 0]

    category_totals = {}
    for item in commodities:
        category = item["category"]
        summary = category_totals.setdefault(category, {"count": 0, "delta_total": 0.0})
        summary["count"] += 1
        summary["delta_total"] += item["delta_percent"]

    categories = [
        {
            "category": category,
            "count": summary["count"],
            "delta_percent": round(summary["delta_total"], 2),
        }
        for category, summary in sorted(category_totals.items())
    ]

    return {
        "rising_count": len(rising),
        "falling_count": len(falling),
        "top_gainers": sorted(rising, key=lambda item: item["delta_percent"], reverse=True)[:5],
        "top_decliners": sorted(falling, key=lambda item: item["delta_percent"])[:5],
        "categories": categories,
    }

@app.get("/api/prices/{commodity}")
def get_historical_prices(commodity: str, days: int = Query(30, ge=7, le=365)):
    """Fetches historical price series for chart rendering."""
    try:
        series = get_commodity_series(commodity).tail(days)
        history = [
            {"date": d.strftime("%Y-%m-%d"), "price": round(float(v), 2)}
            for d, v in series.items() if not pd.isna(v)
        ]
        return {"commodity": commodity, "history": history}
    except Exception as e:
        raise HTTPException(status_code=404, detail=str(e))

@app.get("/api/forecast/{commodity}")
def get_price_forecast(commodity: str, horizon: int = Query(7, ge=1, le=30)):
    """Generates ARIMA forecasts and confidence intervals. ponytail: 6h cache."""
    key = (commodity.lower().strip(), horizon)
    cached = _FORECAST_CACHE.get(key)
    if cached and _time.time() - cached[0] < _FORECAST_TTL:
        return cached[1]
    try:
        result = generate_arima_forecast(commodity, horizon_days=horizon)
        _FORECAST_CACHE[key] = (_time.time(), result)
        return result
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", "8000"))
    uvicorn.run("main:app", host="0.0.0.0", port=port, reload=False)
