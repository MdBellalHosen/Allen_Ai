from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_register_and_stt_requires_token():
    assert client.post("/v1/stt", files={"file": ("a.m4a", b"x")}).status_code == 401
    tok = client.post("/v1/auth/device", json={"device_id": "device-12345678"}).json()["token"]
    # No OPENAI_API_KEY in tests -> 503 proves auth passed and config check ran.
    r = client.post("/v1/stt", files={"file": ("a.m4a", b"x")}, headers={"Authorization": f"Bearer {tok}"})
    assert r.status_code == 503
