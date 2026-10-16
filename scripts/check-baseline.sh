#!/usr/bin/env bash
# Run against this project's disposable local development PostgreSQL only.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

for tool in uv docker; do
    command -v "$tool" >/dev/null || { echo "Missing required command: $tool" >&2; exit 1; }
done
[[ -f .env ]] || { echo "Create .env using docs/SETUP.md first." >&2; exit 1; }

project="${BASELINE_COMPOSE_PROJECT:-helpdesk-automata-baseline}"
compose=(docker compose -p "$project")

uv sync --locked --dev --python 3.14
uv run --locked ruff check .
uv run --locked ruff format --check .
uv run --locked mypy .
"${compose[@]}" config --quiet
"${compose[@]}" up -d postgres_db

ready=false
for ((attempt = 1; attempt <= 30; attempt++)); do
    if "${compose[@]}" exec -T postgres_db sh -c \
        'pg_isready -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"' >/dev/null 2>&1; then
        ready=true
        break
    fi
    sleep 2
done
if [[ "$ready" != true ]]; then
    echo "PostgreSQL was not ready within 60 seconds. Inspect docker compose logs." >&2
    exit 1
fi

uv run --locked alembic upgrade head
uv run --locked alembic current
# Cap workers while preserving the inherited coverage gate and all tests.
uv run --locked pytest -n 2
echo "Baseline checks passed. PostgreSQL remains available for local development."
