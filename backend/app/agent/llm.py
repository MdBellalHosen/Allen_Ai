"""Thin Claude Messages API client (raw httpx: easy to fake in tests)."""
from typing import Protocol

import httpx

from app.config import Settings


class LLMError(Exception):
    pass


class LLM(Protocol):
    async def complete(self, *, system: str, messages: list[dict], tools: list[dict]) -> list[dict]:
        """Returns the assistant's content blocks (dicts with type text / tool_use)."""


class AnthropicClient:
    def __init__(self, settings: Settings, transport: httpx.AsyncBaseTransport | None = None):
        self.s = settings
        self._transport = transport

    async def complete(self, *, system: str, messages: list[dict], tools: list[dict]) -> list[dict]:
        if not self.s.anthropic_api_key:
            raise LLMError("ANTHROPIC_API_KEY is not set")
        if not self.s.llm_model:
            raise LLMError("LLM_MODEL is not set")
        body = {
            "model": self.s.llm_model,
            "max_tokens": self.s.llm_max_tokens,
            "system": system,
            "tools": tools,
            # one UI action at a time: each step depends on the previous result
            "tool_choice": {"type": "auto", "disable_parallel_tool_use": True},
            "messages": messages,
        }
        async with httpx.AsyncClient(timeout=60, transport=self._transport) as c:
            r = await c.post(
                f"{self.s.anthropic_base_url}/v1/messages",
                headers={
                    "x-api-key": self.s.anthropic_api_key,
                    "anthropic-version": "2023-06-01",
                    "content-type": "application/json",
                },
                json=body,
            )
        if r.status_code != 200:
            raise LLMError(f"LLM HTTP {r.status_code}: {r.text[:200]}")
        return r.json().get("content", [])


def _to_openai_messages(system: str, messages: list[dict]) -> list[dict]:
    """Anthropic-style history (tool_use / tool_result blocks) -> OpenAI chat messages."""
    import json

    out: list[dict] = [{"role": "system", "content": system}]
    for m in messages:
        content = m["content"]
        if isinstance(content, str):
            out.append({"role": m["role"], "content": content})
            continue
        if m["role"] == "assistant":
            text = "".join(b.get("text", "") for b in content if b.get("type") == "text")
            calls = [
                {
                    "id": b["id"],
                    "type": "function",
                    "function": {"name": b["name"], "arguments": json.dumps(b.get("input", {}), ensure_ascii=False)},
                }
                for b in content
                if b.get("type") == "tool_use"
            ]
            msg: dict = {"role": "assistant", "content": text or None}
            if calls:
                msg["tool_calls"] = calls
            out.append(msg)
        else:
            texts = []
            for b in content:
                if b.get("type") == "tool_result":
                    c = b.get("content", "")
                    if isinstance(c, list):
                        c = "".join(x.get("text", "") for x in c)
                    out.append({"role": "tool", "tool_call_id": b["tool_use_id"], "content": str(c)})
                elif b.get("type") == "text":
                    texts.append(b["text"])
            if texts:
                out.append({"role": "user", "content": "".join(texts)})
    return out


def _to_openai_tools(tools: list[dict]) -> list[dict]:
    return [
        {
            "type": "function",
            "function": {"name": t["name"], "description": t.get("description", ""), "parameters": t["input_schema"]},
        }
        for t in tools
    ]


class OpenAICompatClient:
    """Any OpenAI-compatible chat endpoint: Groq, Gemini, OpenRouter, Ollama (all have free options)."""

    def __init__(self, settings: Settings, transport: httpx.AsyncBaseTransport | None = None):
        self.s = settings
        self._transport = transport

    async def complete(self, *, system: str, messages: list[dict], tools: list[dict]) -> list[dict]:
        import json

        if not self.s.llm_base_url:
            raise LLMError("LLM_BASE_URL is not set")
        if not self.s.llm_model:
            raise LLMError("LLM_MODEL is not set")
        if not self.s.llm_api_key:
            raise LLMError("LLM_API_KEY is not set")
        body = {
            "model": self.s.llm_model,
            "max_tokens": self.s.llm_max_tokens,
            "messages": _to_openai_messages(system, messages),
            "tools": _to_openai_tools(tools),
            "tool_choice": "auto",
            "parallel_tool_calls": False,
        }
        async with httpx.AsyncClient(timeout=60, transport=self._transport) as c:
            r = await c.post(
                f"{self.s.llm_base_url.rstrip('/')}/chat/completions",
                headers={"Authorization": f"Bearer {self.s.llm_api_key}"},
                json=body,
            )
        if r.status_code == 429:
            raise LLMError("free-tier rate limit reached (HTTP 429); wait a bit and retry")
        if r.status_code != 200:
            raise LLMError(f"LLM HTTP {r.status_code}: {r.text[:200]}")
        try:
            msg = r.json()["choices"][0]["message"]
        except (KeyError, IndexError, ValueError) as e:
            raise LLMError("unexpected LLM response shape") from e
        blocks: list[dict] = []
        if msg.get("content"):
            blocks.append({"type": "text", "text": msg["content"]})
        for tc in (msg.get("tool_calls") or [])[:1]:  # one action at a time
            try:
                args = json.loads(tc["function"].get("arguments") or "{}")
            except ValueError:
                args = {}
            blocks.append(
                {"type": "tool_use", "id": tc.get("id") or "call_0", "name": tc["function"]["name"], "input": args}
            )
        return blocks


def build_llm(settings: Settings) -> LLM:
    if settings.llm_provider == "openai_compat":
        return OpenAICompatClient(settings)
    return AnthropicClient(settings)
