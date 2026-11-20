"""In-memory agent sessions (single backend instance, personal use). Move to Redis for multi-instance."""
import time
import uuid
from dataclasses import dataclass, field
from typing import Any


@dataclass
class Session:
    id: str
    device_id: str
    lang: str = "en"
    messages: list[dict] = field(default_factory=list)
    steps: int = 0
    cancelled: bool = False
    # what the app must answer next: {"kind": "device"|"ask"|"confirm_model"|"confirm_guard", "id": str, "call": dict|None}
    awaiting: dict[str, Any] | None = None
    extra_results: list[dict] = field(default_factory=list)  # tool_results for ignored extra tool_use blocks
    touched: float = field(default_factory=time.time)


class SessionStore:
    def __init__(self, ttl_s: int = 600):
        self.ttl = ttl_s
        self._s: dict[str, Session] = {}

    def _purge(self) -> None:
        now = time.time()
        for k in [k for k, v in self._s.items() if now - v.touched > self.ttl]:
            del self._s[k]

    def create(self, device_id: str) -> Session:
        self._purge()
        s = Session(id=uuid.uuid4().hex, device_id=device_id)
        self._s[s.id] = s
        return s

    def get(self, sid: str, device_id: str) -> Session | None:
        self._purge()
        s = self._s.get(sid)
        if s is None or s.device_id != device_id:
            return None
        s.touched = time.time()
        return s

    def drop(self, sid: str) -> None:
        self._s.pop(sid, None)
