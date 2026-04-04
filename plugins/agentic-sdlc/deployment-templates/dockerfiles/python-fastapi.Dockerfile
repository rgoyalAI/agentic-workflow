# Multi-stage FastAPI / ASGI app — Python 3.12 slim
# Expects: requirements.txt (or pyproject.toml with pip install .)
# Adjust COPY paths to match your project layout.

ARG PYTHON_VERSION=3.12-slim-bookworm
ARG APP_USER=appuser
ARG APP_UID=1001
ARG APP_GID=1001

# --- Build venv ---
FROM python:${PYTHON_VERSION} AS builder
WORKDIR /build

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY requirements.txt .
RUN pip install --upgrade pip setuptools wheel \
    && pip install --no-cache-dir -r requirements.txt

# If using pyproject.toml instead:
# COPY pyproject.toml README.md ./
# COPY src ./src
# RUN pip install --no-cache-dir .

# --- Runtime ---
FROM python:${PYTHON_VERSION} AS runtime

ARG APP_USER
ARG APP_UID
ARG APP_GID

RUN groupadd --gid ${APP_GID} ${APP_USER} \
    && useradd --uid ${APP_UID} --gid ${APP_GID} --home /app --shell /usr/sbin/nologin --system ${APP_USER}

WORKDIR /app

COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Application code (change paths as needed)
COPY --chown=${APP_UID}:${APP_GID} ./src ./src

USER ${APP_UID}:${APP_GID}

EXPOSE 8080

ENV HOST=0.0.0.0 \
    PORT=8080

# Uvicorn: replace `src.main:app` with your module:app
ENTRYPOINT ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8080", "--proxy-headers"]

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/health')" || exit 1

LABEL org.opencontainers.image.title="fastapi-app" \
      org.opencontainers.image.description="FastAPI on Python slim with venv"
