from pathlib import Path

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

from app.api.v1 import agent, auth, stt
from app.config import get_settings
from app.core.logging import setup_logging

setup_logging()
settings = get_settings()

app = FastAPI(title="ALLEN AI backend", version="0.5.0")
app.include_router(auth.router)
app.include_router(stt.router)
app.include_router(agent.router)


app.mount("/app", StaticFiles(directory=Path(__file__).parent / "web", html=True), name="web")


@app.get("/health")
def health() -> dict:
    return {"status": "ok", "env": settings.app_env}
