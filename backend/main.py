from fastapi import FastAPI

from api.v1.best_time import router as best_time_router
from database.connection import check_db_connection

app = FastAPI(title="RouteMind Backend", version="1.0.0")

app.include_router(best_time_router, prefix="/api/v1", tags=["v1"])


@app.get("/health")
def health_check() -> dict:
    db_connected = check_db_connection()
    return {
        "status": "ok",
        "ai_model": "mock/ready",
        "db": "connected" if db_connected else "disconnected",
    }
