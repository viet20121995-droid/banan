#!/bin/bash
set -e
cd /opt/banan
d=/opt/banan/web/internal
t=/tmp/banan-web-internal.tgz
test -s "$t"
rm -rf "$d.new" "$d.old" && mkdir -p "$d.new"
tar xzf "$t" -C "$d.new"
test -s "$d.new/main.dart.js"
if [ -e "$d" ]; then mv "$d" "$d.old"; fi
mv "$d.new" "$d" || { mv "$d.old" "$d" 2>/dev/null; false; }
rm -rf "$d.old"
rm -f "$t"
md5sum "$d/main.dart.js"
docker compose --env-file infra/.env.prod -f docker-compose.prod.yml restart caddy 2>&1 | tail -1
echo SWAP_OK
