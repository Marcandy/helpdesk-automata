# Baseline verification

Verified on October 16, 2026, in a fresh local clone on branch
`chore/initialize-baseline`. This is the inherited template baseline, before any
Ticket or Comment implementation.

## Source identity

- Fork: [Marcandy/helpdesk-automata](https://github.com/Marcandy/helpdesk-automata).
- GitHub metadata identifies it as a fork of
  [rafsaf/minimal-fastapi-postgres-template](https://github.com/rafsaf/minimal-fastapi-postgres-template).
- Initial fork HEAD and fetched upstream `main`:
  `b384f05abc2fb1d06dc39fb1f6855f6c083f5026`.
- The requested setup files match upstream at that commit:
  [README](https://github.com/rafsaf/minimal-fastapi-postgres-template/blob/b384f05abc2fb1d06dc39fb1f6855f6c083f5026/README.md),
  [Makefile](https://github.com/rafsaf/minimal-fastapi-postgres-template/blob/b384f05abc2fb1d06dc39fb1f6855f6c083f5026/Makefile),
  [pyproject](https://github.com/rafsaf/minimal-fastapi-postgres-template/blob/b384f05abc2fb1d06dc39fb1f6855f6c083f5026/pyproject.toml),
  [Compose](https://github.com/rafsaf/minimal-fastapi-postgres-template/blob/b384f05abc2fb1d06dc39fb1f6855f6c083f5026/docker-compose.yml).

## Environment

| Component | Observed value |
| --- | --- |
| Host | Windows, x86-64; Git Bash 5.2.15 |
| System Python | 3.11.5; not used for the application |
| Application Python | CPython 3.14.0, downloaded by uv into workspace-local storage |
| uv | 0.9.2, matching inherited CI; installed under sibling `.baseline-tools` |
| Docker | Client/server 29.8.2; Desktop 4.94.0, Linux containers |
| Compose | v5.5.1 |
| PostgreSQL | 18.6, from the existing floating `postgres:18` tag |
| Dev dependencies | Installed from unchanged `uv.lock`: 65 Windows packages |
| WSL | Ubuntu WSL2 available; Linux Python 3.14.4 observed; uv and make not found in that shell |

Initial sandbox checks could not access the Docker named pipe, WSL, or GitHub
network. The same checks succeeded with approved execution outside the sandbox;
this was not evidence of a broken Docker installation. No global Python, shell
profile, or Windows PATH was changed.

An ignored local `.env` was created from the example with generated JWT and
database secrets. Its contents are not recorded here. The dedicated Compose
project is `helpdesk-automata-baseline`, with a new named database volume and
host database port 5455.

## Results

The documented `bash scripts/check-baseline.sh` ran in Git Bash with the
workspace-local uv on PATH and workspace-local `UV_CACHE_DIR` and
`UV_PYTHON_INSTALL_DIR`. It exited 0.

| Check | Result |
| --- | --- |
| `uv sync --locked --dev --python 3.14` | Passed; lockfile unchanged |
| `uv run --locked ruff check .` | Passed |
| `uv run --locked ruff format --check .` | Passed; 34 files already formatted |
| `uv run --locked mypy .` | Passed; 32 source files |
| `docker compose -p helpdesk-automata-baseline config --quiet` | Passed |
| PostgreSQL start and TCP readiness | Passed |
| `uv run --locked alembic upgrade head` | Passed; applied inherited `initial_auth` migration |
| `uv run --locked alembic current` | `683275eeb305 (head)` |
| `uv run --locked pytest -n 2` | 42 passed in 12.73 seconds; 100% coverage, 245 measured statements |
| `pre-commit install --install-hooks` / `pre-commit run --all-files` | Passed; check-yaml, Ruff format, and Ruff check; inherited hook environments cached under `.baseline-tools` |
| `bash -n scripts/check-baseline.sh` | Passed |
| Local Markdown link check | Passed |
| `git diff --check` | Passed |
| Inherited app/config/license diff | Empty; changes are limited to the README and new docs/script |

The pytest command overrides the inherited automatic worker count with two
workers. It preserves the full suite and its 100% coverage requirement.
Coverage is the configured test metric, not proof of complete behavior or a
security audit.

A temporary Uvicorn process on `localhost:8000` returned HTTP 200 for `/`,
`/openapi.json`, `/probe/live` (`"ok"`), and `/probe/health`
(`"app and database ok"`). It was then stopped with Ctrl+C; application shutdown
completed. PostgreSQL remains running for local development. See
[setup](SETUP.md) for start and stop commands.

## Limits and next step

- Full WSL application setup, Docker image build, and deployment were not run.
- `gh run list` returned no runs for the fork during inspection. CI success has
  not been established.
- The inherited publish workflow still targets rafsaf's Docker Hub repository;
  review it before merging to `main` as described in [setup](SETUP.md).
- The generated environment, uv tool storage, caches, and database volume are
  local state. They are not part of the proposed tracked files.
- No application features or new migrations were added. Existing workflow settings
  are unchanged, and no images were published by this setup task.

Review these local changes, then begin the separately timed manual Ticket and
Comment milestone in [the project plan](PROJECT.md).

The README was subsequently shortened to focus on Helpdesk Automata. Template
tutorials, upstream badges, and the live demo were removed; attribution and the
original license remain. The pinned upstream README linked above retains the
template walkthrough.
