from fastapi.testclient import TestClient

from app.main import app


def test_health():
    r = TestClient(app).get("/health")
    assert r.status_code == 200
    assert r.json()["status"] == "ok"


def test_web_app_served():
    from fastapi.testclient import TestClient

    from app.main import app

    c = TestClient(app)
    assert "ALLEN AI" in c.get("/app/").text
    assert c.get("/app/manifest.webmanifest").json()["short_name"] == "ALLEN"
    assert c.get("/app/icon-192.png").content[:4] == b"\x89PNG"
