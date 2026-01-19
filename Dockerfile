### Base: Setup user and system prerequisites
FROM python:3.12-slim-bookworm AS base

# Fix for slow IPv6 route lookups in some environments (e.g. older K8s/Docker networks, AWS ECS that is IPv4 only)
RUN echo "precedence ::ffff:0:0/96  100" >> /etc/gai.conf

ENV DEBIAN_FRONTEND=noninteractive

# Install runtime dependencies (ca-certificates) here so they exist in final image
RUN \
  apt-get update -qy && \
  apt-get install -qyy \
    -o APT::Install-Recommends=false \
    -o APT::Install-Suggests=false \
    ca-certificates && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN \
  groupadd -r app -g 1001 && \
  useradd -r -d /app -m -g app -u 1001 -N app

WORKDIR /app

### Builder: Install tooling and build the environment
FROM base AS builder

# Install build-only deps
RUN \
  apt-get update -qy && \
  apt-get install -qyy \
    -o APT::Install-Recommends=false \
    -o APT::Install-Suggests=false \
    build-essential && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Pin uv version for reproducibility
COPY --from=ghcr.io/astral-sh/uv:0.9.26 /uv /usr/local/bin/uv

# --- OPTIMIZATION START ---
# 1. Copy only lockfiles first
COPY --chown=app:app pyproject.toml uv.lock /app/

# 2. Install dependencies ONLY (cached layer)
#    We use a cache mount so uv doesn't re-download wheels if the layer is rebuilt.
RUN --mount=type=cache,target=/app/.cache,uid=1001,gid=1001 \
    uv sync \
      --link-mode=copy \
      --compile-bytecode \
      --no-install-project \
      --no-dev \
      --frozen

# 3. Copy the rest of the application code
COPY --chown=app:app . /app

# 4. Install the project itself (fast layer)
RUN --mount=type=cache,target=/app/.cache,uid=1001,gid=1001 \
    uv sync \
      --link-mode=copy \
      --no-dev \
      --frozen \
      --compile-bytecode
# --- OPTIMIZATION END ---

### Runtime: Production image
FROM base AS runtime

ENV HOME=/app \
    USER=app \
    PATH=/app/.venv/bin:$PATH

# Copy the pre-built application and venv from builder
COPY --from=builder --chown=app:app /app /app

USER app

EXPOSE 8000

CMD ["/app/.venv/bin/planar", "prod", "--host", "0.0.0.0", "--port", "8000"]