# syntax=docker/dockerfile:1
# denisqsound.tech — zola build → nginx static runtime.
# Target arch: linux/arm64 (Oracle A1 Ampere / Apple Silicon).

FROM debian:trixie-slim AS build
ARG ZOLA_VERSION=0.23.6
RUN apt-get update \
  && apt-get install -y --no-install-recommends curl ca-certificates \
  && rm -rf /var/lib/apt/lists/*
RUN curl -fsSL "https://github.com/getzola/zola/releases/download/v${ZOLA_VERSION}/zola-v${ZOLA_VERSION}-aarch64-unknown-linux-gnu.tar.gz" \
  | tar -xz -C /usr/local/bin zola
WORKDIR /site
COPY config.toml ./
COPY content ./content
COPY templates ./templates
COPY static ./static
RUN zola build --output-dir /site/public

FROM nginx:1.29-alpine
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /site/public /usr/share/nginx/html
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD wget -q -O /dev/null http://127.0.0.1/ || exit 1
EXPOSE 80
