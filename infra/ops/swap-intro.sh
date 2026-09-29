#!/bin/bash
# Brand site (web-intro/) swap: expects /tmp/banan-web-intro.tgz. Validates the
# Caddyfile (git pull first if it changed) and restarts Caddy.
set -e
cd /opt/banan
# Refuse before touching anything if the (pulled) Caddyfile would not load.
docker compose --env-file infra/.env.prod -f docker-compose.prod.yml exec -T caddy caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile >/dev/null 2>&1 || { echo "Caddyfile invalid"; exit 1; }
d=/opt/banan/web/intro
t=/tmp/banan-web-intro.tgz
test -s "$t"
rm -rf "$d.new" "$d.old" && mkdir -p "$d.new"
tar xzf "$t" -C "$d.new"
test -s "$d.new/index.html"
# Kill switch for the old app's service worker — must always ship.
test -s "$d.new/flutter_service_worker.js"
if [ -e "$d" ]; then mv "$d" "$d.old"; fi
mv "$d.new" "$d" || { mv "$d.old" "$d" 2>/dev/null; false; }
rm -rf "$d.old"
rm -f "$t"
docker compose --env-file infra/.env.prod -f docker-compose.prod.yml restart caddy 2>&1 | tail -1
echo SWAP_OK
