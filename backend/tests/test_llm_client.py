import json

import httpx
import pytest

from app.agent.llm import AnthropicClient, LLMError
from app.agent.tools_schema import ALL_TOOLS
from app.config import Settings


async def test_request_shape_and_parse():
    seen = {}

    def handler(req: httpx.Request) -> httpx.Response:
        seen["headers"] = req.headers
        seen["body"] = json.loads(req.content)
        return httpx.Response(200, json={"content": [{"type": "tool_use", "id": "x", "name": "done", "input": {}}]})

    c = AnthropicClient(Settings(anthropic_api_key="k", llm_model="m"), transport=httpx.MockTransport(handler))
    out = await c.complete(system="sys", messages=[{"role": "user", "content": "hi"}], tools=ALL_TOOLS)
    assert out[0]["name"] == "done"
    assert seen["headers"]["x-api-key"] == "k" and seen["headers"]["anthropic-version"] == "2023-06-01"
    b = seen["body"]
    assert b["model"] == "m" and b["system"] == "sys" and len(b["tools"]) == len(ALL_TOOLS)
    assert b["tool_choice"] == {"type": "auto", "disable_parallel_tool_use": True}


async def test_missing_config():
    with pytest.raises(LLMError):
        await AnthropicClient(Settings(anthropic_api_key="", llm_model="m")).complete(system="", messages=[], tools=[])
    with pytest.raises(LLMError):
        await AnthropicClient(Settings(anthropic_api_key="k", llm_model="")).complete(system="", messages=[], tools=[])


async def test_http_error():
    c = AnthropicClient(Settings(anthropic_api_key="k", llm_model="m"), transport=httpx.MockTransport(lambda r: httpx.Response(529, text="overloaded")))
    with pytest.raises(LLMError, match="529"):
        await c.complete(system="", messages=[], tools=[])


def test_tool_schemas_are_valid():
    names = [t["name"] for t in ALL_TOOLS]
    assert len(names) == len(set(names))
    for t in ALL_TOOLS:
        assert t["input_schema"]["type"] == "object"
        for r in t["input_schema"]["required"]:
            assert r in t["input_schema"]["properties"]
