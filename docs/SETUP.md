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

## Agent container

The `agent` build target is a coding workspace for Claude Code, the project's
AI coding tool. It sees only this project, runs as the non-root user `agent`, and
keeps its Python environment in `/opt/venv`, apart from the host `.venv`.

Build it from Git Bash:

```bash
docker build --target agent -t helpdesk-agent:boundaries .
```

Run it with this project as the only host folder:

```bash
MSYS_NO_PATHCONV=1 docker run --rm -it --network bridge \
  -v "$(pwd -W)":/workspace \
  -v /dev/null:/workspace/.env:ro \
  -v helpdesk-agent-claude:/home/agent/.claude \
  helpdesk-agent:boundaries
```

- `$(pwd -W)` gives Docker a Windows path. `MSYS_NO_PATHCONV=1` stops Git Bash
  from rewriting the container paths.
- `/dev/null:/workspace/.env:ro` hides the real `.env`. The agent sees an empty,
  read-only file; the host file is untouched.
- `helpdesk-agent-claude` is a named volume that keeps the Claude Code login
  between runs. It holds no host files.
- `--rm` deletes the container on exit.
- `--network bridge` is Docker's default network, written out so the choice
  is explicit. The container can reach the internet, which Claude Code needs
  to reach Anthropic. No ports are published, so nothing on your PC or
  network can connect into it.

Never mount your home folder, Desktop, Downloads, `~/.ssh`, cloud credential
folders, or the Docker socket.

### Why hide `.env`

Anything in `/workspace` is readable by the agent, and the agent's output can
leave the machine. Treat the agent as untrusted with secrets: give it none it
does not need. The app falls back to defaults when `.env` is empty, and
environment variables override both, so pass throwaway values with `-e` if a
task needs them. Keep real credentials out of the project folder entirely once
the project has any.

### What persists

| Location | Lifetime | Use for |
| --- | --- | --- |
| `/workspace` | Persists; it is the host project folder | Source code and docs |
| `/home/agent/.claude` | Persists in the `helpdesk-agent-claude` volume | CLI login and settings |
| `/opt/venv` | Rebuilt with the image | Python dependencies |
| `/tmp` and the rest of the container | Deleted on exit | Scratch files, downloads, caches |

Remove the login volume with `docker volume rm helpdesk-agent-claude`.

### Verify the boundary

Run these inside the container:

```bash
id -un                      # agent
ls -A /workspace            # project files
wc -c < /workspace/.env     # 0
grep " /workspace " /proc/self/mountinfo   # one bind mount: this project
ls -A ~/.ssh /mnt /Users 2>&1              # missing or empty
echo scratch > /tmp/scratch && echo keep > /workspace/step4-keep
```

Exit and start a new container: `/workspace/step4-keep` remains and
`/tmp/scratch` is gone. Delete `step4-keep` afterwards.

Verified on November 3, 2026, with Docker Desktop 29.8.2 on Windows. Each check
gave the expected result. The only host mount was this project. `~/.ssh`, `C:\`,
`/Users`, and the Docker socket were absent; `/root` was unreadable; no secrets
appeared in environment variables. The masked `.env` read as 0 bytes inside the
container while the host file was unchanged. The login volume kept a test file
across runs. Running the app or tests inside the container was not checked.

### Smoke test

Run on November 3, 2026. The container was started with the run command above,
named so its changes could be inspected with `docker diff` from a second
terminal. It omitted `--network bridge`, which is Docker's default:

```bash
MSYS_NO_PATHCONV=1 docker run --rm -it --name helpdesk-smoke \
  -v "$(pwd -W)":/workspace \
  -v /dev/null:/workspace/.env:ro \
  -v helpdesk-agent-claude:/home/agent/.claude \
  helpdesk-agent:boundaries
```

Prompt given to Claude Code:

> Summarize this repository's structure: main folders, what each holds, how
> to run tests, and what features exist versus are planned. Write the summary
> to /workspace/agent-summary.md. Do not modify, create, or delete any other
> file.

Each command Claude requested was approved by hand. All were reads inside
`/workspace`, such as `grep` on `app/auth/views.py`, plus the write to
`agent-summary.md`.

Checks on the host after exiting the container:

```text
$ docker ps -a --filter name=helpdesk-smoke
CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES

$ head -5 agent-summary.md
# Helpdesk Automata — repository summary

An async FastAPI + PostgreSQL API intended for managing support tickets and
automating support workflows. It is a fork of rafsaf's MIT-licensed
`minimal-fastapi-postgres-template`; almost all application code is still the

$ git status --short
?? "Dockerfile copy"
?? agent-summary.md

$ git diff --stat
```

Result: pass. The container was deleted on exit, the summary persisted on the
host, and no other project file changed. The summary was reviewed and is
accurate; it correctly reports ticket features as planned, not built.

### Security decisions

These answers are provisional for the first setup and will change as the
project grows. Add tools, files, credentials, or network access to the
container only when a real task needs them.

**Why did you mount only this folder?**
I mounted only the helpdesk-automata folder so the agent can see and change
this project and nothing else on my computer. The container's tools come from
the Docker image; the mount decides which of my files it can reach. My home
folder, SSH keys, other projects, and credential folders are not mounted, so
the agent cannot read or change them. I verified this: the only host mount was
this project, and `~/.ssh`, `C:\`, and `/Users` were not visible inside the
container.

**What did you choose to keep ephemeral?**
I kept the container itself ephemeral. Each run creates a new container from
the same image, and `--rm` deletes it on exit. That removes `/tmp`, caches,
downloads, and anything the agent installed or changed outside the mounted
folders, so every session starts from the same known state. I tested this: a
file written to `/tmp` was gone after a restart.

**What did you choose to persist?**
I persist only two things. The project code persists because `/workspace` is
my real project folder, so the agent's work survives the container. The Claude
Code login persists in a separate named volume, `helpdesk-agent-claude`, so I
stay signed in with the LaunchCode account between runs; that volume holds no
other host files. I deliberately did not persist `.env`. It is never in the
image, because the Dockerfile copies only specific files, and it is masked at
runtime by an empty, read-only file mounted over `/workspace/.env`. The real
file stays on my PC, unchanged. Dependencies are fixed in the image and change
only when I rebuild it.

**What dependencies did you include in your extended Docker image?**
Compared with the course's Dockerfile, my image adds no new dependencies; it
already included what the project needs: Python 3.14, uv, the project's locked
packages (including pytest, Ruff, and mypy), Node 24, and Claude Code 2.1.312.
I removed OpenCode because Claude Code is my only agent. My changes were to
configuration instead: the agent runs as a non-root user, and the agent
workspace is a build target in the project's single Dockerfile.

**What did your smoke test prove?**
The smoke test proved the agent works on this project from inside the
container. Claude Code read the repo, wrote an accurate summary to
`/workspace/agent-summary.md`, and that file was still on my PC after the
container was deleted. `git status` showed it as the only new file, and
`git diff --stat` was empty, so no existing file changed. `docker ps -a` showed
the container was gone. The test showed the agent stayed inside its boundary,
but not that it couldn't leave it: I told it to write one file and approved
each action by hand. The earlier boundary test showed the only host folder
mounted was this project.

**What risks remain?**
The biggest remaining risk is that the agent can change anything in
`/workspace`, including `.git`. A modified Git hook or script would run on my
PC the next time I commit or run it, so I review changes before running
anything the agent touched. The network is open, so the agent could send
project code out or be misled by content it reads. Hiding `.env` depends on
including the mask in every run command, and new secret files wouldn't be
covered; the project also lacks a `.dockerignore`. Finally, safety relies on my
reviewing each action, and base image tags can change between rebuilds. These
are acceptable for a first setup with no production secrets, and I'll revisit
them as the course goes on.

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
