from typing import Any, Literal

from pydantic import BaseModel, Field


class CommandIn(BaseModel):
    transcript: str = Field(min_length=1, max_length=1000)
    locale: Literal["bn", "en"] | None = None
    device_caps: dict[str, Any] = {}


class ToolResultIn(BaseModel):
    id: str
    ok: bool
    message: str = ""
    data: dict[str, Any] | None = None


class ResultIn(BaseModel):
    results: list[ToolResultIn]


class Say(BaseModel):
    text: str
    lang: Literal["bn", "en"]


class ToolCallOut(BaseModel):
    id: str
    name: str
    args: dict[str, Any]


class StepOut(BaseModel):
    session_id: str
    status: Literal["tool_calls", "ask_user", "confirm", "done", "error"]
    say: list[Say] = []
    tool_calls: list[ToolCallOut] = []
    call_id: str | None = None  # id to answer for ask_user / confirm
    question: str | None = None
    preview: str | None = None
    summary: str | None = None
    lang: Literal["bn", "en"] = "en"
    error: str | None = None
