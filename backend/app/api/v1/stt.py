"""Cloud speech-to-text fallback (Whisper). Better Bangla accuracy + auto language detection."""
import httpx
from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from pydantic import BaseModel

from app.config import Settings, get_settings
from app.deps import require_device

router = APIRouter(prefix="/v1/stt", tags=["stt"])

# Whisper returns full language names in verbose_json.
_LANG = {"bengali": "bn", "english": "en", "hindi": "hi", "urdu": "ur"}


class SttOut(BaseModel):
    text: str
    language: str  # "bn" | "en" | other ISO-ish code | "und"


@router.post("", response_model=SttOut)
async def transcribe(
    file: UploadFile = File(...),
    language: str | None = Form(default=None),  # "bn" / "en" hint, or omit for auto-detect
    _device: str = Depends(require_device),
    settings: Settings = Depends(get_settings),
) -> SttOut:
    if not settings.openai_api_key:
        raise HTTPException(503, "cloud STT not configured (OPENAI_API_KEY)")
    data = await file.read()
    if not data:
        raise HTTPException(400, "empty audio")
    if len(data) > settings.stt_max_bytes:
        raise HTTPException(413, "audio too large")

    form = {"model": settings.stt_model, "response_format": "verbose_json"}
    if language in ("bn", "en"):
        form["language"] = language
    async with httpx.AsyncClient(timeout=60) as client:
        r = await client.post(
            "https://api.openai.com/v1/audio/transcriptions",
            headers={"Authorization": f"Bearer {settings.openai_api_key}"},
            data=form,
            files={"file": (file.filename or "audio.m4a", data, file.content_type or "audio/mp4")},
        )
    if r.status_code != 200:
        raise HTTPException(502, "STT provider error")
    j = r.json()
    lang = str(j.get("language", "")).lower()
    return SttOut(text=(j.get("text") or "").strip(), language=_LANG.get(lang, lang or "und"))
