"""Live evaluation of the planner on the command set. Needs ANTHROPIC_API_KEY and LLM_MODEL.
Usage (from backend/):  python -m evals.run_eval          (EVAL_MIN_PASS=0.85 makes it exit 1 below that)"""
import asyncio
import os
import sys

from app.agent.llm import AnthropicClient
from app.agent.planner import AgentPlanner
from app.config import Settings
from evals.command_set import CASES, judge


async def main() -> int:
    s = Settings()
    planner = AgentPlanner(AnthropicClient(s), s)
    sem = asyncio.Semaphore(4)

    async def one(c: dict):
        async with sem:
            step = await planner.start("eval-device", c["said"], None, {"accessibility_enabled": True})
            ok, why = judge(c, step)
            return c, ok, why

    results = await asyncio.gather(*(one(c) for c in CASES))
    passed = sum(1 for _, ok, _ in results if ok)
    lines = [f"Model: {s.llm_model}", f"Pass rate: {passed}/{len(results)} = {passed / len(results):.0%}", ""]
    for style in ("bn", "en", "banglish", "mixed"):
        sub = [r for r in results if r[0]["style"] == style]
        if sub:
            lines.append(f"- {style}: {sum(1 for _, ok, _ in sub if ok)}/{len(sub)}")
    lines += ["", "Failures:"]
    lines += [f"- [{c['style']}] {c['said']!r}: {why}" for c, ok, why in results if not ok] or ["- none"]
    report = "\n".join(lines)
    print(report)
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as f:
            f.write("## Command set evaluation\n```\n" + report + "\n```\n")
    return 0 if passed / len(results) >= float(os.environ.get("EVAL_MIN_PASS", "0")) else 1


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
