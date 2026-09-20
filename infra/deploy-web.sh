#!/bin/bash
# Build the 4 Flutter web apps with production config and upload them to the
# BizFly server, where Caddy serves them statically. Run from the repo root
# on your LOCAL machine (needs Flutter in PATH + ssh/scp/tar — all in Git Bash).
#
#   SERVER=banan BASE_DOMAIN=banancakes.vn bash infra/deploy-web.sh
#
# Optional: REMOTE_DIR (default /opt/banan/web).
set -e

SERVER=${SERVER:?Set SERVER=user@server-ip}
BASE_DOMAIN=${BASE_DOMAIN:-banancakes.vn}
REMOTE_DIR=${REMOTE_DIR:-/opt/banan/web}

API="https://api.${BASE_DOMAIN}/api/v1"
WS="https://api.${BASE_DOMAIN}"
# The ordering app lives on order.<domain>; the root domain is the static brand
# site (web-intro/). Merchant builds its /track/<id> hand-out links from this.
CUST="https://order.${BASE_DOMAIN}"

# BANAN_ENV must be the literal "prod" — Env.isProd compares against it, and
# anything else leaves Dio's LogInterceptor on, printing every request and
# response body (passwords, tokens, customer PII) to the live site's console.
# BANAN_WS_URL stays https:// — socket_io_client upgrades on its own, and a
# wss:// value parses to port 0 (Dart only knows http/https default ports),
# which silently kills realtime.
build_and_upload() {
  local appDir="$1" remoteName="$2"
  echo "▶ Building $appDir …"
  ( cd "apps/$appDir"
    flutter pub get
    flutter build web --release \
      --dart-define=BANAN_API_BASE_URL="$API" \
      --dart-define=BANAN_WS_URL="$WS" \
      --dart-define=BANAN_CUSTOMER_APP_URL="$CUST" \
      --dart-define=BANAN_ENV=prod
    tar czf "/tmp/banan-web-$remoteName.tgz" -C build/web .
  )
  echo "▶ Uploading $remoteName → $SERVER:$REMOTE_DIR/$remoteName …"
  scp "/tmp/banan-web-$remoteName.tgz" "$SERVER:/tmp/"
  # Unpack into a staging dir and prove it holds a real bundle BEFORE touching
  # what Caddy is serving. The obvious `rm -rf && tar xzf` deletes the live site
  # first and only then finds out the tarball is missing or truncated — which
  # takes the storefront down and leaves nothing to roll back to.
  ssh "$SERVER" "
    set -e
    d='$REMOTE_DIR/$remoteName'
    t=/tmp/banan-web-$remoteName.tgz
    test -s \"\$t\"
    rm -rf \"\$d.new\" \"\$d.old\" && mkdir -p \"\$d.new\"
    tar xzf \"\$t\" -C \"\$d.new\"
    test -s \"\$d.new/main.dart.js\"
    # Swap by moving the live copy aside first, not deleting it: if the final
    # move fails, restore the previous copy so the site is never left missing.
    if [ -e \"\$d\" ]; then mv \"\$d\" \"\$d.old\"; fi
    mv \"\$d.new\" \"\$d\" || { mv \"\$d.old\" \"\$d\" 2>/dev/null; false; }
    rm -rf \"\$d.old\"
    rm -f \"\$t\"
  " || {
    echo "✖ $remoteName failed to deploy — the live copy was left untouched" >&2
    return 1
  }
  rm -f "/tmp/banan-web-$remoteName.tgz"
}

# The brand site is plain files — no build. Same stage-verify-swap as the apps.
upload_intro() {
  echo "▶ Uploading intro → $SERVER:$REMOTE_DIR/intro …"
  tar czf /tmp/banan-web-intro.tgz -C web-intro .
  scp /tmp/banan-web-intro.tgz "$SERVER:/tmp/"
  ssh "$SERVER" "
    set -e
    d='$REMOTE_DIR/intro'
    t=/tmp/banan-web-intro.tgz
    test -s \"\$t\"
    rm -rf \"\$d.new\" \"\$d.old\" && mkdir -p \"\$d.new\"
    tar xzf \"\$t\" -C \"\$d.new\"
    test -s \"\$d.new/index.html\"
    # Without the kill switch, returning customers keep getting the old app's
    # cached bundle at the root domain instead of this site.
    test -s \"\$d.new/flutter_service_worker.js\"
    if [ -e \"\$d\" ]; then mv \"\$d\" \"\$d.old\"; fi
    mv \"\$d.new\" \"\$d\" || { mv \"\$d.old\" \"\$d\" 2>/dev/null; false; }
    rm -rf \"\$d.old\"
    rm -f \"\$t\"
  " || {
    echo "✖ intro failed to deploy — the live copy was left untouched" >&2
    return 1
  }
  rm -f /tmp/banan-web-intro.tgz
}

# ONLY=intro ships just the brand site (no Flutter needed).
if [ "${ONLY:-}" = "intro" ]; then
  upload_intro
  echo "✅ Done. Intro site uploaded."
  exit 0
fi

build_and_upload banan_customer customer
build_and_upload banan_merchant merchant
build_and_upload banan_kitchen  kitchen
build_and_upload banan_internal internal
upload_intro

echo "✅ Done. Caddy on $SERVER now serves the updated web apps."
