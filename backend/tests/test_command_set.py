from evals.command_set import CASES


def test_command_set_size_and_styles():
    assert len(CASES) >= 60
    assert len({c["id"] for c in CASES}) == len(CASES)
    styles = {c["style"] for c in CASES}
    assert {"bn", "en", "banglish"} <= styles
    for c in CASES:
        e = c["expect"]
        assert e.get("tools") or e.get("statuses"), c["id"]
