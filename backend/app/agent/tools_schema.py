"""Section 5 tool contract as Anthropic tool definitions. Names are stable: the Flutter ToolDispatcher
implements the device tools; control tools are handled by the planner / app UI."""
from typing import Any

_STR = {"type": "string"}


def _tool(name: str, description: str, props: dict[str, Any] | None = None, required: list[str] | None = None) -> dict:
    return {
        "name": name,
        "description": description,
        "input_schema": {"type": "object", "properties": props or {}, "required": required or []},
    }


DEVICE_TOOLS: list[dict] = [
    _tool(
        "open_app",
        "Open an installed app by its spoken name (e.g. youtube, facebook, whatsapp, camera, settings, or any app label).",
        {"name": {**_STR, "description": "App name in English or Bangla"}},
        ["name"],
    ),
    _tool("open_url", "Open an http(s) URL in the browser or matching app.", {"url": _STR}, ["url"]),
    _tool(
        "search_in_app",
        "Search inside an app using a deep link. Supported apps: youtube, google. For youtube, play_first=true also taps the first result.",
        {"app": {"type": "string", "enum": ["youtube", "google"]}, "query": _STR, "play_first": {"type": "boolean"}},
        ["app", "query"],
    ),
    _tool(
        "tap",
        "Tap a UI element on the current screen by visible text / content description / id (case-insensitive substring; "
        "list alternatives, e.g. English and Bangla labels). Use read_screen first when unsure what is on screen.",
        {
            "match": {"type": "array", "items": _STR, "description": "labels to look for"},
            "clickable_only": {"type": "boolean"},
            "timeout_ms": {"type": "integer", "description": "keep looking this long for the element to appear"},
        },
        ["match"],
    ),
    _tool("type_text", "Type text into the focused or first visible text field.", {"text": _STR}, ["text"]),
    _tool("scroll", "Scroll the current screen.", {"direction": {"type": "string", "enum": ["up", "down"]}}, ["direction"]),
    _tool(
        "press_global",
        "Press a system navigation action.",
        {"action": {"type": "string", "enum": ["back", "home", "recents", "notifications", "quick_settings"]}},
        ["action"],
    ),
    _tool(
        "read_screen",
        "Read the visible screen as a compact list of nodes (text, desc, id, clickable, bounds). Refused on password/payment screens.",
    ),
    _tool(
        "media_control",
        "Control the currently playing media.",
        {"action": {"type": "string", "enum": ["play", "pause", "toggle", "next", "previous", "forward", "rewind", "stop"]}},
        ["action"],
    ),
    _tool(
        "set_volume",
        "Change media volume: either a direction or an absolute level 0-100.",
        {"direction": {"type": "string", "enum": ["up", "down", "mute", "unmute"]}, "level": {"type": "integer", "minimum": 0, "maximum": 100}},
    ),
    _tool(
        "toggle_setting",
        "flashlight is switched directly (set on true/false). wifi, bluetooth, dnd and airplane only OPEN the system panel; "
        "Android requires the user to flip the switch, so say so.",
        {"name": {"type": "string", "enum": ["flashlight", "wifi", "bluetooth", "dnd", "airplane"]}, "on": {"type": "boolean"}},
        ["name"],
    ),
]

CONTROL_TOOLS: list[dict] = [
    _tool(
        "ask_user",
        "Ask the user one short clarifying question (spoken). The answer comes back as the tool result.",
        {"question": _STR, "lang": {"type": "string", "enum": ["bn", "en"]}},
        ["question", "lang"],
    ),
    _tool(
        "confirm",
        "Ask the user to confirm an outward-facing or irreversible action before doing it. Result is 'confirmed' or 'declined'.",
        {"action_preview": {**_STR, "description": "plain-language preview of exactly what will happen"}, "lang": {"type": "string", "enum": ["bn", "en"]}},
        ["action_preview", "lang"],
    ),
    _tool(
        "speak",
        "Say a short progress message aloud and continue working.",
        {"text": _STR, "lang": {"type": "string", "enum": ["bn", "en"]}},
        ["text", "lang"],
    ),
    _tool(
        "done",
        "Finish the task. summary is spoken to the user in one short sentence. ALWAYS end with this.",
        {"summary": _STR, "lang": {"type": "string", "enum": ["bn", "en"]}},
        ["summary", "lang"],
    ),
]

ALL_TOOLS = DEVICE_TOOLS + CONTROL_TOOLS
DEVICE_TOOL_NAMES = {t["name"] for t in DEVICE_TOOLS}
CONTROL_TOOL_NAMES = {t["name"] for t in CONTROL_TOOLS}
