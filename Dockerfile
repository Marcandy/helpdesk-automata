# One Dockerfile: the API is the default image; use --target agent for the course.
FROM node:24-bookworm-slim AS agent-node
FROM python:3.14-slim-trixie AS base

ENV PYTHONUNBUFFERED=1
WORKDIR /build

# Create requirements.txt file
FROM base AS uv
COPY --from=ghcr.io/astral-sh/uv:0.9.2 /uv /uvx /bin/
COPY uv.lock pyproject.toml ./
RUN uv export --no-dev --no-hashes -o /requirements.txt --no-install-workspace --frozen
RUN uv export --only-group dev --no-hashes -o /requirements-dev.txt --no-install-workspace --frozen

FROM base AS api
COPY --from=uv /requirements.txt .

# Create venv, add it to path and install requirements
RUN python -m venv /venv
ENV PATH="/venv/bin:$PATH"
RUN pip install -r requirements.txt

# Install uvicorn server
RUN pip install uvicorn[standard]

# Copy the rest of app
COPY app app
COPY alembic alembic
COPY alembic.ini .
COPY pyproject.toml .
COPY init.sh .

# Expose port 8000 for app and optional 9090 for prometheus metrics
EXPOSE 8000
EXPOSE 9090

# Make the init script executable
RUN chmod +x ./init.sh

# Set ENTRYPOINT to always run init.sh
ENTRYPOINT ["./init.sh"]

# Set CMD to uvicorn
# /venv/bin/uvicorn is used because from entrypoint script PATH is new
CMD ["/venv/bin/uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1", "--loop", "uvloop"]

# Interactive coding workspace, built with: docker build --target agent .
FROM base AS agent
COPY --from=ghcr.io/astral-sh/uv:0.9.2 /uv /uvx /usr/local/bin/
# Node/npm support the course CLIs; application dependencies still use uv.
COPY --from=agent-node /usr/local/bin/node /usr/local/bin/node
COPY --from=agent-node /usr/local/lib/node_modules /usr/local/lib/node_modules

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl git bash ca-certificates nano procps \
    && rm -rf /var/lib/apt/lists/* \
    && ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
    && ln -s /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx

# Keep Linux dependencies outside any mounted Windows/Mac .venv.
ENV UV_PROJECT_ENVIRONMENT=/opt/venv \
    UV_PYTHON_DOWNLOADS=never \
    UV_LINK_MODE=copy
ENV PATH="/opt/venv/bin:${PATH}"
WORKDIR /workspace
COPY pyproject.toml uv.lock ./
RUN --mount=type=cache,target=/root/.cache/uv \
    UV_HTTP_TIMEOUT=120 uv sync --locked --dev --python 3.14

ARG CLAUDE_CODE_VERSION=2.1.312
ARG OPENCODE_VERSION=1.19.4
RUN npm install -g \
    "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}" \
    "opencode-ai@${OPENCODE_VERSION}"

# ngrok is deferred until needed. Missing course settings/statusline/entrypoint
# files are not copied; the CLIs use their defaults and Bash starts directly.
RUN mkdir -p /root/.claude \
    && printf '\nalias ll="ls -alF"\n' >> /root/.bashrc
CMD ["/bin/bash"]

# Preserve the existing API startup for ordinary builds and the publishing CI.
FROM api AS final
