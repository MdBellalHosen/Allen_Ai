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
