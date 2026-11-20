"""Device registration. Personal-use model: one registration code gates token issuing."""
import hmac

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field

from app.config import Settings, get_settings
from app.core.security import create_device_token

router = APIRouter(prefix="/v1/auth", tags=["auth"])


class DeviceRegisterIn(BaseModel):
    device_id: str = Field(min_length=8, max_length=128)
    registration_code: str = ""


class TokenOut(BaseModel):
    token: str


@router.post("/device", response_model=TokenOut)
def register_device(body: DeviceRegisterIn, settings: Settings = Depends(get_settings)) -> TokenOut:
    if settings.registration_code and not hmac.compare_digest(
        body.registration_code, settings.registration_code
    ):
        raise HTTPException(status.HTTP_403_FORBIDDEN, "invalid registration code")
    return TokenOut(
        token=create_device_token(settings.secret_key, body.device_id, settings.device_token_ttl_days)
    )
