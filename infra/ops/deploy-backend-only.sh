#!/bin/bash
# Pull master, rebuild + restart the backend, wait for /health, print the
# migration lines. Fails loudly (non-zero, BACKEND_DEPLOY_FAILED) when the
# image build fails — the old container keeps running in that case.
set -eo pipefail
cd /opt/banan
git pull --ff-only 2>&1 | tail -1
if ! docker compose --env-file infra/.env.prod -f docker-compose.prod.yml build backend >/tmp/backend-build.log 2>&1; then
  grep -iE 'error|failed' /tmp/backend-build.log | grep -v '^\s*$' | tail -15
  echo BACKEND_DEPLOY_FAILED
  exit 1
fi
docker compose --env-file infra/.env.prod -f docker-compose.prod.yml up -d backend 2>&1 | tail -2
code=
for i in $(seq 1 45); do
  code=$(curl -sS -o /dev/null -w '%{http_code}' https://api.banancakes.vn/api/v1/health || true)
  if [ "$code" = "200" ]; then echo "backend healthy after ${i}x2s"; break; fi
  sleep 2
done
test "$code" = "200"
docker compose --env-file infra/.env.prod -f docker-compose.prod.yml logs --tail=60 backend 2>&1 | grep -E "Applying migration|migrations have been|No pending|error" | tail -4 || true
echo BACKEND_DEPLOY_OK
