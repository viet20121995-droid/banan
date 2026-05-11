# Two-stage build: compile Flutter web → serve via tiny nginx.

FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /workspace
COPY . .
WORKDIR /workspace/apps/banan_kitchen
RUN flutter pub get

ARG BANAN_API_BASE_URL=https://banan-api.fly.dev/api/v1
ARG BANAN_WS_URL=wss://banan-api.fly.dev
ARG BANAN_ENV=prod

RUN flutter build web --release \
    --dart-define=BANAN_API_BASE_URL=${BANAN_API_BASE_URL} \
    --dart-define=BANAN_WS_URL=${BANAN_WS_URL} \
    --dart-define=BANAN_ENV=${BANAN_ENV}

FROM nginx:1.27-alpine
COPY --from=build /workspace/apps/banan_kitchen/build/web /usr/share/nginx/html
COPY apps/banan_kitchen/nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 8080
