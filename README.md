# Palengke+ — DA-4A Calabarzon Price Tracker + ARIMA Forecast

Live API: `https://YOUR-RENDER-URL.onrender.com/api/health`

## Backend (FastAPI)
```
cd backend
pip install -r requirements.txt
python main.py          # http://127.0.0.1:8000/docs
```

Env:
- `PORT` — cloud sets it (default 8000)
- `CORS_ORIGINS=*` (default) or `https://your-app.web.app,https://...`
- `DA_SYNC_INTERVAL_SECONDS` — default 21600 (6h)

Health: `GET /api/health` | `GET /api/commodities` | `GET /api/forecast/{commodity}?horizon=7`

## Frontend (Flutter)
```
cd Palengke+_frontend/palengkeplus
flutter pub get
flutter run
```
Set API url in app: gear icon → paste `https://YOUR-RENDER-URL.onrender.com/api`

## Deploy to Render (backend)
1. Push to GitHub
2. Render → New Web Service → connect repo
3. Root Directory: `backend`
4. Build: `pip install -r requirements.txt`
5. Start: `uvicorn main:app --host 0.0.0.0 --port $PORT`
6. Deploy → copy URL → put in Flutter
