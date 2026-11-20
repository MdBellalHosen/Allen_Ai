import time

import pytest

from app.core.security import TokenError, create_device_token, verify_device_token


def test_roundtrip():
    t = create_device_token("s3cret", "device-12345678")
    assert verify_device_token("s3cret", t) == "device-12345678"


def test_wrong_secret_rejected():
    t = create_device_token("a", "device-12345678")
    with pytest.raises(TokenError):
        verify_device_token("b", t)


def test_expired_rejected():
    t = create_device_token("s", "device-12345678", ttl_days=1, now=time.time() - 3 * 86400)
    with pytest.raises(TokenError):
        verify_device_token("s", t)


def test_tampered_rejected():
    t = create_device_token("s", "device-12345678")
    body, sig = t.split(".")
    with pytest.raises(TokenError):
        verify_device_token("s", body[:-1] + ("A" if body[-1] != "A" else "B") + "." + sig)
