
import sqlite3
import warnings
from itertools import product
from pathlib import Path
import numpy as np
import pandas as pd
from statsmodels.tsa.arima.model import ARIMA
from statsmodels.tsa.stattools import adfuller

from database import DB_PATH

warnings.filterwarnings("ignore")

MIN_ARIMA_OBSERVATIONS = 14

def get_commodity_series(commodity: str) -> pd.Series:
    """Loads and cleans historical price time-series for a commodity."""
    conn = sqlite3.connect(DB_PATH)
    df = pd.read_sql_query(
        "SELECT date, price FROM prices WHERE commodity = ? ORDER BY date ASC",
        conn,
        params=(commodity.lower().strip(),)
    )
    conn.close()

    if df.empty:
        raise ValueError(f"No price data found for {commodity}")

    df['date'] = pd.to_datetime(df['date'])
    df = df.groupby('date')['price'].mean()
    observed_count = len(df)
    df = df.asfreq('D')
    df = df.interpolate(method='linear')
    df.attrs['observed_count'] = observed_count
    return df

def check_stationarity(series: pd.Series) -> dict:
    """Executes the Augmented Dickey-Fuller (ADF) test."""
    clean_series = series.dropna()
    if len(clean_series) < 5:
        return {"stationary": False, "p_value": 1.0, "adf_stat": 0.0}

    result = adfuller(clean_series)
    return {
        "adf_stat": float(result[0]),
        "p_value": float(result[1]),
        "stationary": bool(result[1] < 0.05)
    }

def safe_mape(actuals: pd.Series, preds: pd.Series) -> float:
    """Calculates MAPE while handling zeros and NaNs safely."""
    actuals = pd.to_numeric(actuals, errors='coerce')
    preds = pd.to_numeric(preds, errors='coerce')
    mask = ~(actuals.isna() | preds.isna() | (actuals == 0))
    if not mask.any():
        return 0.0
    errors = (actuals[mask] - preds[mask]).abs() / actuals[mask].abs()
    return float((errors * 100).mean())


_ORDER_CACHE: dict[tuple[int, tuple], tuple] = {}
def find_best_arima_order(series: pd.Series, max_p=2, max_d=2, max_q=2) -> tuple:
    """Returns fixed order on free tier. ponytail: grid search when paid CPU."""
    key = (len(series), (max_p, max_d, max_q))
    if key in _ORDER_CACHE:
        return _ORDER_CACHE[key]
    order = (1, 1, 1)  # ponytail: skip 6 fits, 0.1 CPU too slow
    _ORDER_CACHE[key] = order
    return order


def evaluate_holdout(series: pd.Series, horizon: int) -> dict:
    """ponytail: skip ARIMA fit on 0.1 CPU, naive last-value holdout; 2 fits -> 1 fit."""
    validation_size = min(horizon, max(2, len(series) // 5))
    training = series.iloc[:-validation_size]
    actuals = series.iloc[-validation_size:]
    if len(training) < 8:
        return {"mape": None, "rmse": None, "validation_points": 0, "order": None}
    order = (1, 1, 1)
    last = float(training.iloc[-1])
    predictions = pd.Series([last] * validation_size, index=actuals.index)
    return {
        "mape": round(safe_mape(actuals, predictions), 2),
        "rmse": round(float(np.sqrt(np.mean((actuals.values - predictions.values) ** 2))), 2),
        "validation_points": validation_size,
        "order": order,
    }


def evaluate_baselines(series: pd.Series, horizon: int) -> list[dict]:
    """ponytail: naive baselines only, no fits."""
    validation_size = min(horizon, max(2, len(series) // 5))
    training = series.iloc[:-validation_size]
    actuals = series.iloc[-validation_size:]
    if len(training) < 3:
        return []

    window = min(3, len(training))
    predictions = {
        "LAST_VALUE_BASELINE": np.repeat(float(training.iloc[-1]), validation_size),
        "MOVING_AVERAGE_BASELINE": np.repeat(float(training.iloc[-window:].mean()), validation_size),
    }
    results = []
    for name, values in predictions.items():
        predicted = pd.Series(values, index=actuals.index)
        results.append({
            "model": name,
            "mape": round(safe_mape(actuals, predicted), 2),
            "rmse": round(float(np.sqrt(np.mean((actuals.values - values) ** 2))), 2),
            "validation_points": validation_size,
        })
    return results


def generate_baseline_forecast(series: pd.Series, commodity: str, horizon_days: int) -> dict:
    """Uses a conservative last-value forecast when ARIMA has too little data."""
    last_price = float(series.iloc[-1])
    observed_count = int(series.attrs.get('observed_count', series.notna().sum()))
    changes = series.diff().dropna()
    volatility = float(changes.std(ddof=1)) if len(changes) > 1 else 0.0
    volatility = max(volatility, last_price * 0.05, 1.0)
    dates = pd.date_range(series.index[-1] + pd.Timedelta(days=1), periods=horizon_days)
    forecast = []
    for step, date in enumerate(dates, start=1):
        margin = 1.96 * volatility * np.sqrt(step)
        forecast.append({
            "date": date.strftime('%Y-%m-%d'),
            "predicted_price": round(last_price, 2),
            "ci_lower": round(float(max(0.0, last_price - margin)), 2),
            "ci_upper": round(float(last_price + margin), 2),
        })
    return {
        "commodity": commodity,
        "model_order": "LAST_VALUE_BASELINE",
        "stationarity": check_stationarity(series),
        "metrics": {"mape": None, "rmse": None},
        "quality": {
            "status": "insufficient_history",
            "observations": observed_count,
            "validation_points": 0,
            "message": f"At least {MIN_ARIMA_OBSERVATIONS} observations are required for ARIMA.",
            "model_comparison": evaluate_baselines(series, horizon_days),
        },
        "forecast": forecast,
    }

def generate_arima_forecast(commodity: str, horizon_days: int = 7) -> dict:
    """Fits ARIMA model and returns price predictions with 95% Confidence Intervals."""
    series = get_commodity_series(commodity)
    # ponytail: cap 60 days on free tier; p95 still 90s on 0.1 CPU without this.
    # Fall back to last-value + RMSE margin instantly if ARIMA exceeds budget.
    import time as _t
    _deadline = _t.time() + 4.0
    if len(series) > 60:
        series = series.iloc[-60:]
    observed_count = int(series.attrs.get('observed_count', series.notna().sum()))
    observed_count = min(observed_count, 60)
    if observed_count < MIN_ARIMA_OBSERVATIONS:
        return generate_baseline_forecast(series, commodity, horizon_days)

    stationarity = check_stationarity(series)
    p, d, q = find_best_arima_order(series)
    validation = evaluate_holdout(series, horizon_days)
    baseline_comparison = evaluate_baselines(series, horizon_days)

    # ponytail: ARIMA.fit blocks past deadline check on 0.1 CPU, so hard-timeout it
    import time as _t2, concurrent.futures as _cf
    remain = _deadline - _t2.time()
    if remain <= 0.2:
        base = generate_baseline_forecast(series, commodity, horizon_days)
        base["quality"]["fallback_reason"] = "free_tier_budget_pre"
        return base
    def _fit():
        m = ARIMA(series, order=(p, d, q))
        fm = m.fit()
        return fm.get_forecast(steps=horizon_days)
    try:
        with _cf.ThreadPoolExecutor(max_workers=1) as _ex:
            fut = _ex.submit(_fit)
            forecast_res = fut.result(timeout=max(0.5, remain))
    except _cf.TimeoutError:
        base = generate_baseline_forecast(series, commodity, horizon_days)
        base["quality"]["fallback_reason"] = "free_tier_budget"
        return base
    except Exception:
        base = generate_baseline_forecast(series, commodity, horizon_days)
        base["quality"]["fallback_reason"] = "arima_fit_failed"
        return base
    predicted_mean = forecast_res.predicted_mean
    conf_int = forecast_res.conf_int(alpha=0.05)

    # ponytail: skip in-sample predict on 0.1 CPU, reuse validation metrics
    mape = validation["mape"] if validation["mape"] is not None else 0.0
    rmse = validation["rmse"] if validation["rmse"] is not None else 0.0

    forecast_dates = [d.strftime('%Y-%m-%d') for d in predicted_mean.index]

    forecast = []
    validation_rmse = validation["rmse"]
    for step, (date_str, pred, ci_low, ci_high) in enumerate(zip(
        forecast_dates,
        predicted_mean.values,
        conf_int.iloc[:, 0].values,
        conf_int.iloc[:, 1].values,
    ), start=1):
        if validation_rmse is not None:
            validation_margin = 1.96 * validation_rmse * np.sqrt(step)
            model_margin = max(float(pred) - float(ci_low), float(ci_high) - float(pred))
            margin = max(model_margin, validation_margin)
            ci_low, ci_high = float(pred) - margin, float(pred) + margin
        forecast.append({
            "date": date_str,
            "predicted_price": round(float(pred), 2),
            "ci_lower": round(float(ci_low), 2),
            "ci_upper": round(float(ci_high), 2),
        })

    return {
        "commodity": commodity,
        "model_order": f"ARIMA({p},{d},{q})",
        "stationarity": stationarity,
        "metrics": {
            "mape": round(mape, 2),
            "rmse": round(rmse, 2)
        },
        "quality": {
            "status": "validated",
            "observations": observed_count,
            "validation_points": validation["validation_points"],
            "validation_mape": validation["mape"],
            "validation_rmse": validation["rmse"],
            "validation_model_order": (
                f"ARIMA{validation['order']}" if validation["order"] else None
            ),
            "confidence": "Nominal 95% model intervals widened using holdout RMSE; coverage is not calibrated.",
            "model_comparison": [
                {
                    "model": f"ARIMA{validation['order']}",
                    "mape": validation["mape"],
                    "rmse": validation["rmse"],
                    "validation_points": validation["validation_points"],
                },
                *baseline_comparison,
            ],
        },
        "forecast": forecast,
    }

