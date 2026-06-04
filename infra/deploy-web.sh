#!/bin/bash
# Build the 3 Flutter web apps with production config and upload them to the
# BizFly server, where Caddy serves them statically. Run from the repo root
# on your LOCAL machine (needs Flutter in PATH + ssh/scp/tar — all in Git Bash).
#
#   SERVER=banan@<server-ip> BASE_DOMAIN=banan.com bash infra/deploy-web.sh
#
# Optional: REMOTE_DIR (default /opt/banan/web).
set -e

SERVER=${SERVER:?Set SERVER=user@server-ip}
BASE_DOMAIN=${BASE_DOMAIN:-banan.com}
REMOTE_DIR=${REMOTE_DIR:-/opt/banan/web}

API="https://api.${BASE_DOMAIN}/api/v1"
WS="https://api.${BASE_DOMAIN}"
CUST="https://${BASE_DOMAIN}"

build_and_upload() {
  local appDir="$1" remoteName="$2"
  echo "▶ Building $appDir …"
  ( cd "apps/$appDir"
    flutter pub get
    flutter build web --release \
      --dart-define=BANAN_API_BASE_URL="$API" \
      --dart-define=BANAN_WS_URL="$WS" \
      --dart-define=BANAN_CUSTOMER_APP_URL="$CUST" \
      --dart-define=BANAN_ENV=production
    tar czf "/tmp/banan-web-$remoteName.tgz" -C build/web .
  )
  echo "▶ Uploading $remoteName → $SERVER:$REMOTE_DIR/$remoteName …"
  scp "/tmp/banan-web-$remoteName.tgz" "$SERVER:/tmp/"
  ssh "$SERVER" "rm -rf '$REMOTE_DIR/$remoteName' && mkdir -p '$REMOTE_DIR/$remoteName' && tar xzf '/tmp/banan-web-$remoteName.tgz' -C '$REMOTE_DIR/$remoteName' && rm -f '/tmp/banan-web-$remoteName.tgz'"
  rm -f "/tmp/banan-web-$remoteName.tgz"
}

build_and_upload banan_customer customer
build_and_upload banan_merchant merchant
build_and_upload banan_kitchen  kitchen

echo "✅ Done. Caddy on $SERVER now serves the updated web apps."
