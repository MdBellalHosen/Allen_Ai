"""Server-side guardrails applied to every device tool call the model proposes, whatever the prompt says.
The phone also enforces SensitiveScreenGuard; this is the second layer."""
import re
from dataclasses import dataclass

from app.agent.tools_schema import DEVICE_TOOL_NAMES

# Labels that mean "this tap sends / publishes / deletes / pays / calls".
_RISKY_ASCII = [
    "send", "post", "share", "publish", "tweet", "reply", "submit", "delete", "remove", "unsend", "block", "unfriend",
    "pay", "buy", "purchase", "order", "checkout", "place order", "transfer", "confirm payment", "call", "dial", "withdraw",
]
_RISKY_BN = [
    "পাঠান", "পাঠাও", "সেন্ড", "পোস্ট", "শেয়ার", "প্রকাশ", "মুছ", "ডিলিট", "রিমুভ", "পেমেন্ট", "পরিশোধ", "কিনুন", "কিনি",
    "অর্ডার", "ট্রান্সফার", "কল", "ডায়াল", "উত্তোলন",
]
_ASCII_RE = re.compile(r"\b(" + "|".join(re.escape(w) for w in _RISKY_ASCII) + r")\b", re.IGNORECASE)


@dataclass
class Verdict:
    allowed: bool = True
    needs_confirmation: bool = False
    reason: str = ""
    label: str = ""  # what the user is being asked to approve


def _is_risky_label(s: str) -> bool:
    return bool(_ASCII_RE.search(s)) or any(w in s for w in _RISKY_BN)


def check(name: str, args: dict) -> Verdict:
    if name not in DEVICE_TOOL_NAMES:
        return Verdict(allowed=False, reason=f"unknown_tool:{name}")

    if name == "tap":
        for label in args.get("match") or []:
            if isinstance(label, str) and _is_risky_label(label):
                return Verdict(needs_confirmation=True, label=label, reason="risky_tap")

    if name == "open_url":
        url = str(args.get("url", "")).strip()
        scheme = url.split(":", 1)[0].lower() if ":" in url else ""
        if scheme in ("tel", "sms", "smsto", "mailto"):
            return Verdict(needs_confirmation=True, label=url, reason="outward_url")
        if scheme not in ("http", "https"):
            return Verdict(allowed=False, reason=f"blocked_url_scheme:{scheme or 'none'}")

    return Verdict()


def confirmation_text(v: Verdict, lang: str) -> str:
    if lang == "bn":
        return f"আমি “{v.label}” চাপ দিতে যাচ্ছি। ঠিক আছে?"
    return f"I'm about to tap “{v.label}”. Is that okay?"
