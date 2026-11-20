"""Claude tool-use loop. The phone executes device tools; the planner decides, applies guardrails,
and yields to the app whenever it needs a device action, an answer, or a confirmation."""
import json
import re
from pathlib import Path

from app.agent import guardrails
from app.agent.llm import LLM
from app.agent.session import Session, SessionStore
from app.agent.tools_schema import ALL_TOOLS, DEVICE_TOOL_NAMES
from app.config import Settings
from app.schemas.agent import Say, StepOut, ToolCallOut, ToolResultIn

SYSTEM_PROMPT = (Path(__file__).parent / "prompts" / "system_bn_en.md").read_text(encoding="utf-8")
_BN = re.compile(r"[ঀ-৿]")
_MAX_RESULT_CHARS = 6000


def _wrap_result(ok: bool, message: str, data: dict | None, tool_name: str) -> str:
    payload = json.dumps({"ok": ok, "message": message, "data": data}, ensure_ascii=False)
    if len(payload) > _MAX_RESULT_CHARS:
        payload = payload[:_MAX_RESULT_CHARS] + "…(truncated)"
    if tool_name == "read_screen":
        # Screen text is attacker-controllable (any app/website). Mark it as data.
        return f"<screen_untrusted>{payload}</screen_untrusted>"
    return payload


class AgentPlanner:
    def __init__(self, llm: LLM, settings: Settings, store: SessionStore | None = None):
        self.llm = llm
        self.s = settings
        self.store = store or SessionStore(settings.agent_session_ttl_s)

    # ---- public API -------------------------------------------------------------------------
    async def start(self, device_id: str, transcript: str, locale: str | None, caps: dict) -> StepOut:
        s = self.store.create(device_id)
        s.lang = "bn" if _BN.search(transcript) else (locale or "en")
        context = {**caps, "locale": locale}
        s.messages.append(
            {
                "role": "user",
                "content": f"<device_caps>{json.dumps(context, ensure_ascii=False)}</device_caps>\nUser said: {transcript}",
            }
        )
        return await self._advance(s, [])

    async def submit(self, device_id: str, sid: str, results: list[ToolResultIn]) -> StepOut | None:
        s = self.store.get(sid, device_id)
        if s is None:
            return None
        aw = s.awaiting
        if aw is None:
            return self._error(s, "nothing_pending")
        by_id = {r.id: r for r in results}
        r = by_id.get(aw["id"])
        say: list[Say] = []

        if aw["kind"] == "confirm_guard":
            call = aw["call"]
            if r is not None and r.message == "confirmed":
                s.awaiting = {"kind": "device", "id": call["id"], "call": call, "name": call["name"]}
                return StepOut(
                    session_id=s.id, status="tool_calls", lang=s.lang,  # type: ignore[arg-type]
                    tool_calls=[ToolCallOut(id=call["id"], name=call["name"], args=call["input"])],
                )
            block = self._result_block(aw["id"], False, "user_declined", None, "")
        elif aw["kind"] in ("ask", "confirm_model"):
            text = r.message if r is not None else ""
            block = {"type": "tool_result", "tool_use_id": aw["id"], "content": text or "(no answer)"}
        else:  # device
            if r is None:
                block = self._result_block(aw["id"], False, "no_result_reported", None, aw.get("name", ""))
            else:
                block = self._result_block(aw["id"], r.ok, r.message, r.data, aw.get("name", ""))
        return await self._advance(s, [block], say)

    def cancel(self, device_id: str, sid: str) -> bool:
        s = self.store.get(sid, device_id)
        if s is None:
            return False
        s.cancelled = True
        self.store.drop(sid)
        return True

    # ---- internals --------------------------------------------------------------------------
    @staticmethod
    def _result_block(tool_use_id: str, ok: bool, message: str, data: dict | None, tool_name: str) -> dict:
        return {
            "type": "tool_result",
            "tool_use_id": tool_use_id,
            "content": _wrap_result(ok, message, data, tool_name),
            "is_error": not ok,
        }

    def _error(self, s: Session, msg: str) -> StepOut:
        return StepOut(session_id=s.id, status="error", error=msg, lang=s.lang)  # type: ignore[arg-type]

    def _done(self, s: Session, summary: str, lang: str | None, say: list[Say]) -> StepOut:
        self.store.drop(s.id)
        return StepOut(
            session_id=s.id, status="done", summary=summary, say=say,
            lang=(lang if lang in ("bn", "en") else s.lang),  # type: ignore[arg-type]
        )

    async def _advance(self, s: Session, pending_blocks: list[dict], say: list[Say] | None = None) -> StepOut:
        say = say if say is not None else []
        blocks = list(pending_blocks)
        while True:
            if blocks or s.extra_results:
                s.messages.append({"role": "user", "content": blocks + s.extra_results})
                s.extra_results = []
                blocks = []
            if s.cancelled:
                return self._done(s, "cancelled", s.lang, say)
            if s.steps >= self.s.agent_max_steps:
                return self._done(s, "Step limit reached." if s.lang == "en" else "ধাপের সীমা শেষ।", s.lang, say)
            s.steps += 1
            try:
                content = await self.llm.complete(system=SYSTEM_PROMPT, messages=s.messages, tools=ALL_TOOLS)
            except Exception as e:  # noqa: BLE001 - surface any provider failure to the app
                self.store.drop(s.id)
                return StepOut(session_id=s.id, status="error", error=str(e)[:300], lang=s.lang, say=say)  # type: ignore[arg-type]
            s.messages.append({"role": "assistant", "content": content})

            uses = [b for b in content if b.get("type") == "tool_use"]
            if not uses:
                text = " ".join(b.get("text", "") for b in content if b.get("type") == "text").strip()
                return self._done(s, text, s.lang, say)

            first, extras = uses[0], uses[1:]
            s.extra_results = [
                {"type": "tool_result", "tool_use_id": e["id"], "content": "skipped: one tool at a time", "is_error": True}
                for e in extras
            ]
            name, args = first["name"], first.get("input") or {}
            lang = args.get("lang") if args.get("lang") in ("bn", "en") else s.lang

            if name == "speak":
                say.append(Say(text=str(args.get("text", "")), lang=lang))  # type: ignore[arg-type]
                blocks = [{"type": "tool_result", "tool_use_id": first["id"], "content": "spoken"}]
                continue
            if name == "done":
                return self._done(s, str(args.get("summary", "")), lang, say)
            if name == "ask_user":
                s.awaiting = {"kind": "ask", "id": first["id"]}
                return StepOut(session_id=s.id, status="ask_user", question=str(args.get("question", "")), call_id=first["id"], say=say, lang=lang)  # type: ignore[arg-type]
            if name == "confirm":
                s.awaiting = {"kind": "confirm_model", "id": first["id"]}
                return StepOut(session_id=s.id, status="confirm", preview=str(args.get("action_preview", "")), call_id=first["id"], say=say, lang=lang)  # type: ignore[arg-type]

            if name not in DEVICE_TOOL_NAMES:
                blocks = [self._result_block(first["id"], False, f"unknown_tool:{name}", None, name)]
                continue
            v = guardrails.check(name, args)
            if not v.allowed:
                blocks = [self._result_block(first["id"], False, f"blocked_by_policy:{v.reason}", None, name)]
                continue
            if v.needs_confirmation:
                s.awaiting = {"kind": "confirm_guard", "id": first["id"], "call": {"id": first["id"], "name": name, "input": args}}
                return StepOut(session_id=s.id, status="confirm", preview=guardrails.confirmation_text(v, s.lang), call_id=first["id"], say=say, lang=s.lang)  # type: ignore[arg-type]

            s.awaiting = {"kind": "device", "id": first["id"], "name": name}
            return StepOut(
                session_id=s.id, status="tool_calls", say=say, lang=s.lang,  # type: ignore[arg-type]
                tool_calls=[ToolCallOut(id=first["id"], name=name, args=args)],
            )
