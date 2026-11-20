from fastapi import FastAPI

from app.api.v1 import agent, auth, stt
from app.config import get_settings
from app.core.logging import setup_logging

setup_logging()
settings = get_settings()

app = FastAPI(title="ALLEN AI backend", version="0.4.0")
app.include_router(auth.router)
app.include_router(stt.router)
app.include_router(agent.router)


@app.get("/health")
def health() -> dict:
    return {"status": "ok", "env": settings.app_env}
