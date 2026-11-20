"""Stateless signed device tokens (HMAC-SHA256). Stdlib only so it is easy to test."""
import base64
import hashlib
import hmac
import json
import time


class TokenError(Exception):
    pass


def _b64e(b: bytes) -> str:
    return base64.urlsafe_b64encode(b).rstrip(b"=").decode()


def _b64d(s: str) -> bytes:
    return base64.urlsafe_b64decode(s + "=" * (-len(s) % 4))


def _sign(secret: str, body: str) -> str:
    return _b64e(hmac.new(secret.encode(), body.encode(), hashlib.sha256).digest())


def create_device_token(secret: str, device_id: str, ttl_days: int = 90, now: float | None = None) -> str:
    exp = int((now if now is not None else time.time()) + ttl_days * 86400)
    body = _b64e(json.dumps({"did": device_id, "exp": exp}, separators=(",", ":")).encode())
    return f"{body}.{_sign(secret, body)}"


def verify_device_token(secret: str, token: str, now: float | None = None) -> str:
    """Return the device id, or raise TokenError."""
    try:
        body, sig = token.split(".", 1)
    except ValueError as e:
        raise TokenError("malformed token") from e
    if not hmac.compare_digest(sig, _sign(secret, body)):
        raise TokenError("bad signature")
    try:
        data = json.loads(_b64d(body))
    except Exception as e:  # noqa: BLE001
        raise TokenError("bad payload") from e
    if data.get("exp", 0) < (now if now is not None else time.time()):
        raise TokenError("expired")
    return str(data["did"])
