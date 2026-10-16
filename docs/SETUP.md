# Local setup

Use Windows Git Bash for the setup tested in this checkout. WSL2 Ubuntu is also
an option; its full application setup has not been verified here. Keep each
platform's checkout and virtual environment separate.

## Verified source configuration

The fork and upstream `main` both resolved to
`b384f05abc2fb1d06dc39fb1f6855f6c083f5026` on October 16, 2026. Their README,
Makefile, pyproject, Compose, Dockerfile, environment example, and lockfile match.

| File | Setup consequence |
| --- | --- |
| `pyproject.toml` | Python `>=3.14,<3.15`; dev dependencies include pytest, Ruff, mypy, pre-commit, and Uvicorn. |
| `uv.lock` | Commit this existing lockfile unchanged; install with `--locked`. Windows excludes uvloop through a platform marker. |
| `docker-compose.yml` | Only `postgres_db`, using `postgres:18`; no API service or healthcheck. Named volume mounts `/var/lib/postgresql`. |
| `.env.example` | Host API connects to `localhost:5455`; database name is `default_db`. Settings use double underscores. |
| `Makefile` | `up` starts PostgreSQL, migrates, and runs the host API. `test` and `lint` also start PostgreSQL. `.env` is a separate target, not a prerequisite of `up`. |
| `app/main.py` | Swagger UI is `/`, OpenAPI is `/openapi.json`. |
| `app/conftest.py` | Tests drop and recreate `test_db_gw*` databases; use only an isolated local database with database-creation privileges. |

## Windows Git Bash

1. Start Docker Desktop with Linux containers. Confirm both client and server
   appear in `docker version`; a working CLI alone does not prove engine access.
2. Install Git for Windows if needed. Open **Git Bash**, not PowerShell, for the
   Bash blocks below. GNU Make is optional and is not bundled by default.
3. Install uv if `uv --version` fails. To match the inherited CI, run this in
   PowerShell, then reopen Git Bash:

   ```powershell
   powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/0.9.2/install.ps1 | iex"
   ```

   See the [official uv installation guide](https://docs.astral.sh/uv/getting-started/installation/)
   for reviewing the installer or using a package manager. Version 0.9.2 is the
   inherited CI version, not a claim about the latest uv release.

Clone only if you do not already have a checkout:

```bash
git clone https://github.com/Marcandy/helpdesk-automata.git
cd helpdesk-automata
git remote -v
# Add this only if `upstream` is absent:
git remote add upstream https://github.com/rafsaf/minimal-fastapi-postgres-template.git
```

Do not run `git init` inside the clone. For this prepared checkout, enter its
existing directory instead. A workspace-local uv was installed for verification;
in Git Bash you can expose it for the current shell without changing your profile:

```bash
export PATH="$(cd ../.baseline-tools/bin && pwd):$PATH"
export UV_CACHE_DIR="$(cd ../.baseline-tools && pwd)/uv-cache"
export UV_PYTHON_INSTALL_DIR="$(cd ../.baseline-tools && pwd)/python"
uv --version
```

The `.baseline-tools` shortcut applies only to the prepared checkout. For other
clones, use your installed uv. Install the exact locked dependencies:

```bash
uv sync --locked --dev --python 3.14
uv run --locked python --version
```

uv can download the required Python; the existing system Python 3.11 does not
satisfy this repository. `uv run` selects the virtual environment, so activation
and bare `pip install` commands are unnecessary. Do not regenerate the lockfile
to work around installation errors; capture and diagnose the first error.

Create `.env` only when it is absent, then generate a local JWT secret and
database password without printing either value:

```bash
if [ ! -e .env ]; then
  cp .env.example .env
  uv run --locked python - <<'PY'
import re
import secrets
from pathlib import Path

path = Path('.env')
text = path.read_text()
for key in ('SECURITY__JWT_SECRET_KEY', 'DATABASE__PASSWORD'):
    text = re.sub(rf'(?m)^{key}=.*$', f'{key}={secrets.token_hex(32)}', text)
path.write_text(text)
PY
fi
git check-ignore .env
```

The prepared checkout already has an ignored `.env` with generated secrets.
Preserve an existing file. Keep `DATABASE__HOSTNAME=localhost` and
`DATABASE__PORT=5455` for the host API. If that port is occupied, select a free
port in `.env` before starting Compose. Environment variables override `.env`;
clear stale `DATABASE__*` overrides before running checks. Changing credentials
after PostgreSQL has initialized a volume does not change its stored credentials.

Run the baseline from Git Bash:

```bash
bash scripts/check-baseline.sh
```

The script stops on errors, checks formatting and types, validates Compose,
starts PostgreSQL, waits up to 60 seconds for TCP readiness, applies existing
migrations, and runs all tests with two workers and the existing 100% coverage
gate. The project name `helpdesk-automata-baseline` isolates its container and
volume names. It does not isolate a conflicting published port or a host-side
database override. It leaves PostgreSQL running. Keep using the same project
name for subsequent Compose commands.

Start the API after a successful baseline:

```bash
uv run --locked uvicorn app.main:app --reload --host localhost --port 8000
```

In another terminal, verify HTTP responses, then open the UI:

```bash
curl --fail http://localhost:8000/openapi.json
curl --fail http://localhost:8000/probe/health
```

Swagger UI: <http://localhost:8000/>. Stop Uvicorn with Ctrl+C.

Install and run the inherited hooks separately:

```bash
uv run --locked pre-commit install --install-hooks
uv run --locked pre-commit run --all-files
git diff --check
git status --short
```

The Ruff hooks can modify files; inspect any diff and rerun the hooks if they
report fixes. The baseline script uses non-mutating Ruff checks. pre-commit
checks tracked files; include newly authored files in your review and staging
before treating the hook run as final validation of them.

Stop the dedicated database without deleting its volume:

```bash
docker compose -p helpdesk-automata-baseline down
```

Keep the named volume. Do not add `-v` unless you intend to erase this project's
local data. Test fixtures leave worker databases behind and recreate them on the
next run. The inherited Compose port mapping listens on host interfaces; use it
for local development and stop it when finished.

## WSL2 Ubuntu alternative

Use a Linux checkout such as `~/projects/helpdesk-automata`, rather than sharing
the Windows `.venv`. Windows and Linux virtual environments are incompatible.
In Docker Desktop, enable Ubuntu under Settings > Resources > WSL Integration;
see [Docker's WSL documentation](https://docs.docker.com/desktop/features/wsl/).

Inside Ubuntu, install Git/curl if missing. GNU Make is optional:

```bash
sudo apt update
sudo apt install git curl make
curl -LsSf https://astral.sh/uv/0.9.2/install.sh | sh
export PATH="$HOME/.local/bin:$PATH"
uv --version
docker version
docker compose version
```

Clone the fork into your Linux home directory, then follow the same dependency,
`.env`, baseline, hook, and API steps above. Skip the Windows-only
`.baseline-tools` PATH block. Confirm `localhost:5455` reaches PostgreSQL from
WSL before assuming its networking is ready. If Docker is not available there,
fix Desktop integration first. Do not start a second copy while the Windows
database occupies the same port.

`make up`, `make test`, and `make lint` are conveniences once GNU Make and a
compatible shell are installed. Their default Compose project name differs from
this guide. To reuse this guide's database, prefix a Make command with
`COMPOSE_PROJECT_NAME=helpdesk-automata-baseline`. The direct script is preferred
for first setup because the Makefile does not wait for database readiness.

## CI before merging to main

The inherited `tests.yml` and `type_check.yml` run on pushes, use Ubuntu and
Python 3.14, and install uv 0.9.2. Tests use a PostgreSQL 18 service. A local
passing run does not establish the fork's Actions status.

`dev_build.yml` still logs into Docker Hub with `DOCKER_USER`/`DOCKER_PASS` and
pushes `rafsaf/minimal-fastapi-postgres-template`. Its automatic trigger follows
test runs on `main`; it can also be started manually. Review and disable that workflow
in the fork's Actions UI before merging to `main`, or separately change its image
destination for this project. Do not add publishing credentials to the inherited
workflow. This setup work preserves all existing workflows and does not publish
an image or change GitHub settings.

If a command fails, save its exit code and relevant error without copying `.env`
contents. Check `docker compose -p helpdesk-automata-baseline ps` and logs for
database failures. Do not report migrations, HTTP checks, tests, or CI as passed
until each has actually succeeded.
