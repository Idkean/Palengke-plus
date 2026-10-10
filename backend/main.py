import asyncio
import contextlib
import logging
import os
from contextlib import asynccontextmanager

import time as _time

import hashlib
import pandas as pd
from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel

from database import DB_PATH, init_db, get_conn, _adapt, USE_POSTGRES
try:
    from piece_weights import PIECE_WEIGHT_KG, per_piece_estimate, piece_weight
except Exception:
    PIECE_WEIGHT_KG = {}
    def per_piece_estimate(c, p): return None
    def piece_weight(c): return None
from forecaster import generate_arima_forecast, get_commodity_series
from sync_da_prices import sync as sync_da_prices

# fix stale-CDN: API up but edge/Proxy caches 4-day-old JSON
def _no_store(resp: JSONResponse) -> JSONResponse:
    resp.headers["Cache-Control"] = "no-store, no-cache, must-revalidate, max-age=0"
    resp.headers["Pragma"] = "no-cache"
    resp.headers["Expires"] = "0"
    return resp
_FORECAST_CACHE: dict[tuple, tuple] = {}  # (commodity,horizon,source) -> (ts, result)
_FORECAST_TTL = 6 * 60 * 60
_FORECAST_TTL_BAD = 5 * 60  # ponytail: baseline/insufficient cached 5m not 6h so thin-DB busts fast

logger = logging.getLogger(__name__)
DA_SYNC_INTERVAL_SECONDS = int(os.getenv("DA_SYNC_INTERVAL_SECONDS", str(6 * 60 * 60)))
raw_cors = os.getenv("CORS_ORIGINS", "*")
if raw_cors.strip() == "*":
    cors_origins = ["*"]
else:
    cors_origins = [o.strip() for o in raw_cors.split(",") if o.strip()]
allow_creds = False if cors_origins == ["*"] else True


async def _prewarm_forecast_cache(done: asyncio.Event):
    # ponytail: warm cache off-request so first user hits instant; stdlib only
    await asyncio.sleep(12)  # let first health/commodities serve before CPU work
    try:
        conn = get_conn()
        try:
            cur = conn.cursor()
            cur.execute(_adapt("SELECT DISTINCT commodity FROM prices"))
            rows = cur.fetchall()
        finally:
            conn.close()
        commodities = [r[0] for r in rows]
        for name in commodities:
            key = (name.lower().strip(), 7, "da")
            if key in _FORECAST_CACHE:
                ts, res = _FORECAST_CACHE[key]
                ttl = _FORECAST_TTL_BAD if res.get("quality", {}).get("status") == "insufficient_history" else _FORECAST_TTL
                if _time.time() - ts < ttl:
                    continue
            try:
                result = await asyncio.to_thread(generate_arima_forecast, name, horizon_days=7, source="da")
                _FORECAST_CACHE[key] = (_time.time(), result)
                logger.info("prewarm cached %s", name)
            except Exception:
                logger.exception("prewarm failed for %s", name)
            await asyncio.sleep(0.3)  # yield so requests not starved
    except Exception:
        logger.exception("prewarm loop failed")
    finally:
        done.set()

async def _maybe_sync_now() -> int:
    # ponytail: eager sync if DB empty or latest < today (fixes "yesterday" stale)
    try:
        from datetime import date as _date
        conn = get_conn()
        try:
            cur = conn.cursor()
            cur.execute(_adapt("SELECT COUNT(*), MAX(date) FROM prices"))
            cnt, latest = cur.fetchone()
        finally:
            conn.close()
        today = _date.today().isoformat()
        stale = cnt == 0 or (latest is not None and latest < today)
        if not stale:
            return 0
        logger.info("DB stale (cnt=%s latest=%s today=%s) -> eager DA sync", cnt, latest, today)
        return await asyncio.to_thread(sync_da_prices)
    except Exception:
        logger.exception("eager sync check failed")
        return 0

async def da_sync_loop(prewarm_done: asyncio.Event):
    # fix: never block DA sync on forecast prewarm; 90s timeout on 0.1 CPU starved sync -> 4-day stale
    imported = 0
    try:
        imported = await _maybe_sync_now()
        if imported:
            logger.info("eager DA sync imported %s observations", imported)
            _FORECAST_CACHE.clear()
            prewarm_done.clear()
            await _prewarm_forecast_cache(prewarm_done)
    except Exception:
        logger.exception("eager DA sync failed")
    if not imported:
        await asyncio.sleep(DA_SYNC_INTERVAL_SECONDS)
    while True:
        try:
            imported = await asyncio.to_thread(sync_da_prices)
            logger.info("DA background sync imported %s observations", imported)
            if imported:
                _FORECAST_CACHE.clear()
            prewarm_done.clear()
            await _prewarm_forecast_cache(prewarm_done)
        except Exception:
            logger.exception("DA background sync failed; keeping the last valid database")
        await asyncio.sleep(DA_SYNC_INTERVAL_SECONDS)


@asynccontextmanager
async def lifespan(app):
    init_db()
    prewarm_done = asyncio.Event()
    prewarm_task = asyncio.create_task(_prewarm_forecast_cache(prewarm_done))
    sync_task = asyncio.create_task(da_sync_loop(prewarm_done))
    try:
        yield
    finally:
        for task in (prewarm_task, sync_task):
            task.cancel()
            with contextlib.suppress(asyncio.CancelledError):
                await task

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

@app.api_route("/", methods=["GET", "HEAD"])
@app.api_route("/health", methods=["GET", "HEAD"])
@app.api_route("/api", methods=["GET", "HEAD"])
def liveness():
    """Liveness probe never hits DB. Fixes Render/UptimeRobot 502 when DB slow."""
    return _no_store(JSONResponse({"status": "ok"}))


@app.api_route("/api/health", methods=["GET", "HEAD"])
def health_check():
    """Detailed DB health. Keep DB work here only; liveness above stays fast."""
    try:
        conn = get_conn()
        try:
            cur = conn.cursor()
            cur.execute(_adapt("SELECT COUNT(*), MAX(date) FROM prices"))
            row = cur.fetchone()
        finally:
            conn.close()
        record_count, latest_date = row
        return _no_store(JSONResponse({
            "status": "ok",
            "database": "postgres" if USE_POSTGRES else "sqlite",
            "price_records": record_count,
            "latest_price_date": latest_date,
        }))
    except Exception as e:
        logger.exception("health check failed")
        return _no_store(JSONResponse({"status": "error", "detail": str(e)}, status_code=500))


@app.api_route("/api/admin/sync", methods=["GET", "POST"])
async def trigger_sync():
    """Manually triggers DA sync (real PDFs) and returns new counts. ponytail: Postgres persists; SQLite fallback for local dev."""
    try:
        imported = await asyncio.to_thread(sync_da_prices)
        if imported:
            _FORECAST_CACHE.clear()
        conn = get_conn()
        try:
            cur = conn.cursor()
            cur.execute(_adapt("SELECT COUNT(*), MAX(date) FROM prices"))
            row = cur.fetchone()
        finally:
            conn.close()
        return {"imported": imported, "price_records": row[0], "latest_price_date": row[1], "source": "DA-4A live PDFs"}
    except Exception as e:
        logger.exception("Manual sync failed")
        raise HTTPException(status_code=500, detail=str(e))

class VendorPriceIn(BaseModel):
    commodity: str
    price: float
    unit: str
    vendor_name: str
    market: str
    notes: str = ""

@app.get("/api/vendor-prices")
def list_vendor_prices(commodity: str | None = None):
    conn = get_conn()
    try:
        cur = conn.cursor()
        if commodity:
            cur.execute(
                _adapt("SELECT id, date, commodity, price, unit, vendor_name, market, notes FROM vendor_prices WHERE commodity = ? ORDER BY date DESC, id DESC"),
                (commodity.lower().strip(),),
            )
            rows = cur.fetchall()
        else:
            cur.execute(
                _adapt("SELECT id, date, commodity, price, unit, vendor_name, market, notes FROM vendor_prices ORDER BY date DESC, id DESC")
            )
            rows = cur.fetchall()
    finally:
        conn.close()
    return {"vendor_prices": [{"id": r[0], "date": r[1], "commodity": r[2], "price": r[3], "unit": r[4], "vendor_name": r[5], "market": r[6], "notes": r[7]} for r in rows]}

@app.post("/api/vendor-prices")
def create_vendor_price(payload: VendorPriceIn):
    commodity = payload.commodity.lower().strip()
    unit = payload.unit.strip().lower()
    vendor = payload.vendor_name.strip()
    market = payload.market.strip()
    if not commodity:
        raise HTTPException(status_code=400, detail="commodity required")
    if payload.price <= 0 or payload.price > 100000:
        raise HTTPException(status_code=400, detail="price must be > 0")
    allowed = {"per kg", "per piece", "per bundle", "per sack", "per pack"}
    if unit not in allowed:
        raise HTTPException(status_code=400, detail=f"unit must be one of {sorted(allowed)}")
    if not vendor or not market:
        raise HTTPException(status_code=400, detail="vendor_name and market required")
    if len(vendor) > 60 or len(market) > 60:
        raise HTTPException(status_code=400, detail="vendor/market too long")
    from datetime import date as _d
    today = _d.today().isoformat()
    conn = get_conn()
    try:
        cur = conn.cursor()
        if USE_POSTGRES:
            cur.execute(
                _adapt("INSERT INTO vendor_prices (date, commodity, price, unit, vendor_name, market, notes) VALUES (?, ?, ?, ?, ?, ?, ?) RETURNING id"),
                (today, commodity, round(float(payload.price), 2), unit, vendor, market, payload.notes.strip()[:200]),
            )
            new_id = cur.fetchone()[0]
        else:
            cur.execute(
                _adapt("INSERT INTO vendor_prices (date, commodity, price, unit, vendor_name, market, notes) VALUES (?, ?, ?, ?, ?, ?, ?)"),
                (today, commodity, round(float(payload.price), 2), unit, vendor, market, payload.notes.strip()[:200]),
            )
            cur.execute("SELECT last_insert_rowid()")
            new_id = cur.fetchone()[0]
        conn.commit()
        for k in list(_FORECAST_CACHE.keys()):
            if len(k)==3 and k[2]=="vendor":
                _FORECAST_CACHE.pop(k,None)
    finally:
        conn.close()
    return {"ok": True, "id": new_id}

def _hash_pw(pw: str) -> str:
    return hashlib.sha256(pw.encode()).hexdigest()

class VendorAuthIn(BaseModel):
    username: str
    password: str
    market: str = ""

@app.post("/api/vendor-auth/register")
def vendor_register(payload: VendorAuthIn):
    u=payload.username.strip().lower()
    pw=payload.password.strip()
    m=payload.market.strip()
    if len(u)<3 or len(pw)<4:
        raise HTTPException(status_code=400, detail="username >=3 and password >=4 required")
    if len(m)<2:
        raise HTTPException(status_code=400, detail="market required")
    conn=get_conn()
    try:
        cur=conn.cursor()
        cur.execute(_adapt("SELECT id FROM vendor_users WHERE username=?"), (u,))
        if cur.fetchone():
            raise HTTPException(status_code=400, detail="username taken")
        from datetime import date as _d
        cur.execute(_adapt("INSERT INTO vendor_users (username,password_hash,market,created_at) VALUES (?,?,?,?)"), (u, _hash_pw(pw), m, _d.today().isoformat()))
        if USE_POSTGRES:
            cur.execute(_adapt("SELECT id FROM vendor_users WHERE username=?"), (u,))
            nid=cur.fetchone()[0]
        else:
            cur.execute("SELECT last_insert_rowid()")
            nid=cur.fetchone()[0]
        conn.commit()
    finally:
        conn.close()
    return {"ok": True, "id": nid, "username": u}

@app.post("/api/vendor-auth/login")
def vendor_login(payload: VendorAuthIn):
    u=payload.username.strip().lower()
    pw=payload.password.strip()
    conn=get_conn()
    try:
        cur=conn.cursor()
        cur.execute(_adapt("SELECT id, password_hash, market FROM vendor_users WHERE username=?"), (u,))
        row=cur.fetchone()
        if not row or row[1]!=_hash_pw(pw):
            raise HTTPException(status_code=401, detail="invalid credentials")
        return {"ok": True, "id": row[0], "username": u, "market": row[2]}
    finally:
        conn.close()

@app.delete("/api/vendor-prices/{vid}")
def delete_vendor_price(vid: int, username: str = Query("")):
    conn=get_conn()
    try:
        cur=conn.cursor()
        cur.execute(_adapt("SELECT vendor_name FROM vendor_prices WHERE id=?"), (vid,))
        row=cur.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="not found")
        if username and row[0].strip().lower()!=username.strip().lower():
            raise HTTPException(status_code=403, detail="not owner")
        cur.execute(_adapt("DELETE FROM vendor_prices WHERE id=?"), (vid,))
        conn.commit()
        # bust vendor forecast cache
        for k in list(_FORECAST_CACHE.keys()):
            if len(k)==3 and k[2]=="vendor":
                _FORECAST_CACHE.pop(k,None)
    finally:
        conn.close()
    return {"ok": True}

def _get_commodities_data():
    """Inner fetch without JSONResponse wrapper. ponytail: avoids JSONResponse subscript bug that broke /api/analytics 500."""
    conn = get_conn()
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
    commodities=[]
    for row in rows:
        name=row[0]
        price=row[2]
        w=piece_weight(name)
        est=per_piece_estimate(name, price)
        commodities.append({
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
                "piece_weight_kg": w,
                "per_piece_estimate": est,
                "per_piece_label": "est." if est is not None and name.lower().strip()!="eggs (medium)" else None,
        })
    return {"commodities": commodities}


@app.get("/api/commodities")
def list_commodities():
    """Lists commodities with category, latest price, and daily movement. No-store fixes stale CDN."""
    return _no_store(JSONResponse(_get_commodities_data()))


@app.get("/api/analytics")
def get_analytics():
    analytics = _get_analytics_data()
    return _no_store(JSONResponse(analytics))

def _get_analytics_data():  # split for no-store wrapper
    """Returns price movement summaries for the analytics dashboard."""
    commodities = _get_commodities_data()["commodities"]
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
async def get_price_forecast(commodity: str, horizon: int = Query(7, ge=1, le=30), source: str = Query("da", pattern="^(da|vendor)$")):
    """Generates ARIMA forecasts. ponytail: to_thread so 0.1 CPU not block health/analytics."""
    key = (commodity.lower().strip(), horizon, source)
    cached = _FORECAST_CACHE.get(key)
    if cached:
        ts, res = cached
        ttl = _FORECAST_TTL_BAD if res.get("quality", {}).get("status") == "insufficient_history" else _FORECAST_TTL
        if _time.time() - ts < ttl:
            return res
    try:
        result = await asyncio.to_thread(generate_arima_forecast, commodity, horizon, source)
        if isinstance(result, dict) and "source" not in result:
            result["source"]=source
        _FORECAST_CACHE[key] = (_time.time(), result)
        return result
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", "8000"))
    uvicorn.run("main:app", host="0.0.0.0", port=port, reload=False)
