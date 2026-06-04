#!/bin/bash
# Cloudflare Pages build for the Banan CUSTOMER web app.
#   Build command:           bash apps/banan_customer/build.sh
#   Build output directory:  apps/banan_customer/build/web
# Edit the domains below to match production before first deploy.
set -e
cd "$(dirname "$0")"

# Cloudflare Pages has no Flutter preinstalled — clone it (cached between builds).
if [ ! -d "$HOME/flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$HOME/flutter"
fi
export PATH="$HOME/flutter/bin:$PATH"
git config --global --add safe.directory "$HOME/flutter" || true

flutter --version
flutter pub get
flutter build web --release \
  --dart-define=BANAN_API_BASE_URL=https://api.banan.com/api/v1 \
  --dart-define=BANAN_WS_URL=https://api.banan.com \
  --dart-define=BANAN_CUSTOMER_APP_URL=https://banan.com \
  --dart-define=BANAN_ENV=production
