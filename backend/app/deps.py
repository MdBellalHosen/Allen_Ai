"""FastAPI dependencies."""
from fastapi import Depends, Header, HTTPException, status

from app.config import Settings, get_settings
from app.core.security import TokenError, verify_device_token


def require_device(
    authorization: str | None = Header(default=None),
    settings: Settings = Depends(get_settings),
) -> str:
    """Returns the authenticated device id from `Authorization: Bearer <token>`."""
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "missing bearer token")
    try:
        return verify_device_token(settings.secret_key, authorization[7:].strip())
    except TokenError as e:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, str(e)) from e
