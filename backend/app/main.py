from fastapi import FastAPI

from app.config import get_settings
from app.core.logging import setup_logging

setup_logging()
settings = get_settings()

app = FastAPI(title="ALLEN AI backend", version="0.1.0")


@app.get("/health")
def health() -> dict:
    return {"status": "ok", "env": settings.app_env}
