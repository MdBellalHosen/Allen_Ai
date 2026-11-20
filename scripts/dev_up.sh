#!/usr/bin/env bash
# Start the dev stack (Phase 1)
set -euo pipefail
cd "$(dirname "$0")/.."
[ -f .env ] || cp .env.example .env
docker compose up --build
