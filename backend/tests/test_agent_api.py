from fastapi.testclient import TestClient

from app.agent.planner import AgentPlanner
from app.agent.session import SessionStore
from app.config import Settings
from app.deps import get_planner
from app.main import app
from tests.test_planner_commands import FakeLLM, tu


def _client(script):
    s = Settings()
    planner = AgentPlanner(FakeLLM(script), s, SessionStore(60))
    app.dependency_overrides[get_planner] = lambda: planner
    return TestClient(app)


def _token(c, device="device-12345678"):
    return c.post("/v1/auth/device", json={"device_id": device}).json()["token"]


def test_requires_token():
    c = _client([])
    assert c.post("/v1/agent/command", json={"transcript": "hi"}).status_code == 401


def test_full_roundtrip_over_http():
    c = _client([[tu("t1", "open_app", name="youtube")], [tu("t2", "done", summary="ok", lang="en")]])
    h = {"Authorization": f"Bearer {_token(c)}"}
    a = c.post("/v1/agent/command", json={"transcript": "open youtube", "locale": "en"}, headers=h).json()
    assert a["status"] == "tool_calls" and a["tool_calls"][0]["name"] == "open_app"
    b = c.post(f"/v1/agent/{a['session_id']}/result", json={"results": [{"id": "t1", "ok": True, "message": "opened"}]}, headers=h).json()
    assert b["status"] == "done" and b["summary"] == "ok"


def test_other_device_gets_404_and_unknown_session_404():
    c = _client([[tu("t1", "read_screen")]])
    h1 = {"Authorization": f"Bearer {_token(c, 'device-aaaaaaaa')}"}
    h2 = {"Authorization": f"Bearer {_token(c, 'device-bbbbbbbb')}"}
    a = c.post("/v1/agent/command", json={"transcript": "x"}, headers=h1).json()
    assert c.post(f"/v1/agent/{a['session_id']}/result", json={"results": []}, headers=h2).status_code == 404
    assert c.post("/v1/agent/nope/result", json={"results": []}, headers=h1).status_code == 404
