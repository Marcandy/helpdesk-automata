# Helpdesk Automata — repository summary

An async FastAPI + PostgreSQL API intended for managing support tickets and
automating support workflows. It is a fork of rafsaf's MIT-licensed
`minimal-fastapi-postgres-template`; almost all application code is still the
inherited template. Version `0.1.0-alpha`, Python `>=3.14,<3.15`, managed with `uv`.

## Main folders

| Path | Contents |
| --- | --- |
| `app/` | Application package. `main.py` builds the FastAPI app (Swagger UI at `/`, OpenAPI at `/openapi.json`) and mounts the routers; `conftest.py` holds pytest fixtures (creates/drops per-worker `test_db_gw*` databases). |
| `app/auth/` | Authentication: SQLAlchemy models (`auth_user`, `auth_refresh_token`), JWT creation/verification, bcrypt password hashing, Pydantic schemas, dependencies (current user), and routes in `views.py`. |
| `app/auth/tests/` | Tests for JWT, password hashing, and each auth endpoint. |
| `app/core/` | Shared infrastructure: settings (`config.py`, pydantic-settings with `SECTION__KEY` env vars), async DB session, declarative `Base` model, app lifespan, Prometheus metrics. |
| `app/probe/` | Liveness/health endpoints and their tests. |
| `app/tests/` | Test helpers: auth helpers and polyfactory factories. |
| `alembic/` | Migration environment; one migration (`683275eeb305 initial_auth`) creating the auth tables. |
| `docs/` | `SETUP.md` (Windows Git Bash / WSL2 setup, agent container), `BASELINE.md` (verification record from 2026-10-16), `PROJECT.md` (scope and planned work). |
| `scripts/` | `check-baseline.sh`: full local check (sync, ruff, mypy, Compose, Postgres readiness, migrations, pytest). |
| `.github/workflows/` | `tests.yml` (pytest against a Postgres 18 service), `type_check.yml` (ruff check, ruff format --check, mypy), `dev_build.yml` (Docker image push — still targets the upstream author's Docker Hub repo). |

Root files: `Dockerfile` (multi-stage: `api`/`final` runtime image and an
`agent` target used as a sandboxed Claude Code workspace), `Dockerfile copy`
(an older, shorter variant), `docker-compose.yml` (Postgres 18 only, host port
from `.env`, default 5455), `Makefile`, `pyproject.toml`, `uv.lock`,
`alembic.ini`, `init.sh` (container entrypoint that runs migrations),
`.env.example`, `.pre-commit-config.yaml`, `agenticEngineerCourse.md` (course
instructions that motivate this project as a "target codebase"), and a
generated `coverage.xml`.

## Running tests

Tests need a running PostgreSQL that the configured user can create databases
in (fixtures drop and recreate `test_db_gw*` databases — use only a disposable
local database).

- Full baseline (recommended first run): `bash scripts/check-baseline.sh`
  — requires `uv`, Docker, and a `.env` (copy from `.env.example`; see `docs/SETUP.md`).
- Make: `make test` (starts Compose Postgres, then `uv run pytest .`).
- Direct: `docker compose up -d` then `uv run pytest` (or `uv run --locked pytest -n 2`).

Pytest config (`pyproject.toml`) runs in parallel (`-n auto`) with coverage and
**fails under 100% coverage**. Lint/type checks: `make lint`, or
`uv run ruff check .`, `uv run ruff format --check .`, `uv run mypy .` (strict).
The baseline record reports 42 tests passing at 100% coverage.

## Features — existing

All inherited from the template:

- Auth (`/auth`): register (`POST /auth/register`), login for access token
  (`POST /auth/access-token`), refresh token (`POST /auth/refresh-token`), get
  current user (`GET /auth/me`), delete current user (`DELETE /auth/me`), reset
  password (`POST /auth/reset-password`). JWT access + stored refresh tokens, bcrypt hashing.
- Probes (`/probe`): `GET /probe/live` → `"ok"`; `GET /probe/health` checks DB connectivity.
- Prometheus metrics (start/stop counters; enabled via `PROMETHEUS__*` settings).
- Tooling: Alembic migrations, Docker image, Compose DB, pre-commit (check-yaml,
  ruff format, ruff check), GitHub Actions CI, a sandboxed agent container target.

## Features — planned (per `README.md` and `docs/PROJECT.md`)

None of these exist in code yet:

1. **Next milestone (manual):** Ticket and Comment models, create/list endpoints,
   migration, factories, and tests — to be implemented by hand and timed.
2. **Later agent-assisted candidates:**
   - SLA deadline filtering and pagination
   - Customer/agent/admin access control and audit history
   - Ticket status workflow validation
   - Structured AI triage (labels, evaluation dataset, cost budget)

Open housekeeping noted in the docs: `dev_build.yml` should be disabled or
repointed before merging to `main`; fork CI status was not yet established;
running the app/tests inside the agent container has not been verified.
