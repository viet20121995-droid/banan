# Two-stage build: compile Flutter web → serve via tiny nginx.
# The Flutter SDK is cached in the build image; final runtime is ~20 MB.

# ─── Stage 1: Flutter build ───────────────────────────────────────────────
FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /workspace

# Copy the whole monorepo so workspace path-deps resolve.
# .dockerignore at the repo root keeps this lean.
COPY . .

# Resolve path dependencies for this app, then build web release.
WORKDIR /workspace/apps/banan_customer
RUN flutter pub get

ARG BANAN_API_BASE_URL=https://banan-api.fly.dev/api/v1
ARG BANAN_WS_URL=wss://banan-api.fly.dev
ARG BANAN_ENV=prod

RUN flutter build web --release \
    --dart-define=BANAN_API_BASE_URL=${BANAN_API_BASE_URL} \
    --dart-define=BANAN_WS_URL=${BANAN_WS_URL} \
    --dart-define=BANAN_ENV=${BANAN_ENV}

# ─── Stage 2: static-file server ──────────────────────────────────────────
FROM nginx:1.27-alpine
COPY --from=build /workspace/apps/banan_customer/build/web /usr/share/nginx/html
COPY apps/banan_customer/nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 8080
