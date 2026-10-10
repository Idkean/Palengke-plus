"""
Per-piece weight estimates for Palengke+ DA commodities.
All DA-4A Bantay Presyo feeds are per kg except eggs (per piece).
per_piece_estimate = per_kg * weight_kg — labeled 'est.' in UI.
Vendor manual per piece prices override this estimate (true price).

Ponytail: replace with DB table when weights need admin edit.
"""
PIECE_WEIGHT_KG: dict[str, float] = {
    "well-milled rice": 1.0,
    "regular milled rice": 1.0,
    "premium 5% broken rice": 1.0,
    "yellow corn": 0.25,
    "ampalaya": 0.15,
    "kamatis": 0.08,
    "talong": 0.15,
    "repolyo": 0.80,
    "sitaw": 0.02,
    "kalabasa": 1.20,
    "carrots": 0.06,
    "red onion": 0.06,
    "white onion": 0.06,
    "bawang": 0.04,
    "luya": 0.05,
    "pork liempo": 0.20,
    "pork kasim": 0.20,
    "beef rump": 0.20,
    "chicken (whole)": 1.40,
    "eggs (medium)": 0.06,
    "bangus": 0.50,
    "tilapia": 0.35,
    "galunggong": 0.08,
}

def per_piece_estimate(commodity: str, per_kg: float) -> float | None:
    w = PIECE_WEIGHT_KG.get(commodity.lower().strip())
    if w is None or per_kg is None:
        return None
    # eggs already stored per piece — return native price
    if commodity.lower().strip() == "eggs (medium)":
        return round(float(per_kg), 2)
    return round(float(per_kg) * w, 2)

def piece_weight(commodity: str) -> float | None:
    return PIECE_WEIGHT_KG.get(commodity.lower().strip())
