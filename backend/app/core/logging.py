"""Logging setup. Cloud debug logs stay off unless the user opts in (Phase 6)."""
import logging


def setup_logging(level: int = logging.INFO) -> None:
    logging.basicConfig(level=level, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
