### Multi-stage build for uv-based app

FROM python:3.12-slim-bookworm AS base

#ipv4 precedence
RUN echo "precedence ::ffff:0:0/96  100" >> /etc/gai.conf

ENV DEBIAN_FRONTEND=noninteractive

RUN \
  groupadd -r app -g 1001 && \
  useradd -r -d /app -m -g app -u 1001 -N app

WORKDIR /app


### Builder: install build tooling, uv, and create the production venv
FROM base AS builder

RUN \
  apt-get update -qy && \
  apt-get install -qyy \
    -o APT::Install-Recommends=false \
    -o APT::Install-Suggests=false \
    build-essential \
    ca-certificates && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv
COPY --chown=app:app . /app

USER app

# App user home is `/app`, so uv will use `/app/.cache` to store downloads.
# To prevent uv from re-downloading packages every time we build, use
# a build time volume mounted at /app/.cache
RUN --mount=type=cache,target=/app/.cache,uid=1001,gid=1001 \
    uv sync \
      --link-mode=copy \
      --compile-bytecode \
      --no-dev \
      --frozen


FROM base AS runtime

ENV DEBIAN_FRONTEND=noninteractive \
    HOME=/app \
    USER=app \
    LOGNAME=app \
    PATH=/app/.venv/bin:$PATH

### copy built app/venv and expose runtime entrypoint
COPY --from=builder --chown=app:app /app /app

USER app

EXPOSE 8000

CMD ["/app/.venv/bin/planar", "prod", "--host", "0.0.0.0", "--port", "8000"]