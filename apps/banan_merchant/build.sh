#!/bin/bash
# Cloudflare Pages build for the Banan MERCHANT web app.
#   Build command:           bash apps/banan_merchant/build.sh
#   Build output directory:  apps/banan_merchant/build/web
set -e
cd "$(dirname "$0")"

if [ ! -d "$HOME/flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$HOME/flutter"
fi
export PATH="$HOME/flutter/bin:$PATH"
git config --global --add safe.directory "$HOME/flutter" || true

flutter --version
flutter pub get
# BANAN_CUSTOMER_APP_URL is not optional here: order_detail_screen builds the
# customer's tracking link from it, and without it Env falls back to
# http://localhost:8081 — staff would hand out a link that only opens on their
# own machine.
flutter build web --release \
  --dart-define=BANAN_API_BASE_URL=https://api.banancakes.vn/api/v1 \
  --dart-define=BANAN_WS_URL=https://api.banancakes.vn \
  --dart-define=BANAN_CUSTOMER_APP_URL=https://banancakes.vn \
  --dart-define=BANAN_ENV=prod
