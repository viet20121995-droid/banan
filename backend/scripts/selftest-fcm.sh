#!/bin/bash
# FCM push self-test. Registers a fake device token, fires both push paths
# (broadcast + order-status), and checks the backend log to confirm the
# Firebase Admin SDK authenticated with Google and processed the send.
# Exit code = number of failures.
API=${API:-http://localhost:3000/api/v1}
LOG=${LOG:-/tmp/banan-backend.log}
PASS=0; FAIL=0; ERRORS=()
pass(){ PASS=$((PASS+1)); printf "  \033[32m✓\033[0m %s\n" "$1"; }
fail(){ FAIL=$((FAIL+1)); ERRORS+=("$1"); printf "  \033[31m✗\033[0m %s\n" "$1"; }
login(){ curl -s -X POST "$API/auth/login" -H "Content-Type: application/json" -d "{\"emailOrPhone\":\"$1\",\"password\":\"banan123\"}" | grep -oE '"accessToken":"[^"]+"' | sed 's/.*:"//;s/"//'; }

CT=$(login customer@banan.local)
MT=$(login merchant@banan.local)
[ -n "$CT" ] && pass "Customer login" || fail "Customer login"

# Wait for a log line matching $1 to appear (up to ~15s).
wait_log(){ for i in $(seq 1 15); do grep -qE "$1" "$LOG" 2>/dev/null && return 0; sleep 1; done; return 1; }

echo "▶ 1 · Broadcast push path"
FAKE1="fcmtest-${RANDOM}${RANDOM}-aaaaaaaaaaaaaaaaaaaaaaaaaaaa"
curl -s -X POST "$API/me/devices" -H "Authorization: Bearer $CT" -H "Content-Type: application/json" \
  -d "{\"platform\":\"WEB\",\"token\":\"$FAKE1\"}" | grep -q '"id"' \
  && pass "Register fake WEB device token" || fail "Register device token"

MARK="FCMTEST-BROADCAST-${RANDOM}"
curl -s -X POST "$API/merchant/broadcast" -H "Authorization: Bearer $MT" -H "Content-Type: application/json" \
  -d "{\"title\":\"$MARK\",\"body\":\"kiem tra push\"}" | grep -q '"recipients"' \
  && pass "Broadcast accepted" || fail "Broadcast call"

if wait_log "Push broadcast ok="; then
  LINE=$(grep "Push broadcast ok=" "$LOG" | tail -1)
  pass "Backend ran broadcast push: $(echo "$LINE" | grep -oE 'Push broadcast ok=[0-9]+/[0-9]+( pruned=[0-9]+)?')"
else
  if grep -q "Push fan-out failed" "$LOG"; then
    fail "FCM send FAILED (credential?): $(grep 'Push fan-out failed' "$LOG" | tail -1 | tail -c 160)"
  else
    fail "No broadcast push log line found"
  fi
fi

# FCM init line proves the service account cert parsed + project loaded.
if grep -q "FCM initialised" "$LOG"; then
  pass "FCM initialised: $(grep 'FCM initialised' "$LOG" | tail -1 | grep -oE 'project [^)]*')"
else
  fail "FCM not initialised (check FCM_SERVICE_ACCOUNT_PATH / file)"
fi

# Fake token should have been pruned (invalid-argument) — proves Google
# accepted the request and returned a per-token rejection we acted on.
PRUNED=$(docker exec banan-postgres psql -U banan -d banan -t -c \
  "SELECT count(*) FROM \"DeviceToken\" WHERE token = '$FAKE1';" 2>/dev/null | tr -d ' \n')
[ "$PRUNED" = "0" ] && pass "Fake token pruned after send (FCM authenticated OK)" \
  || fail "Fake token NOT pruned (count=$PRUNED) — send may not have reached FCM"

echo "▶ 2 · Order-status push path"
FAKE2="fcmtest-${RANDOM}${RANDOM}-bbbbbbbbbbbbbbbbbbbbbbbbbbbb"
curl -s -X POST "$API/me/devices" -H "Authorization: Bearer $CT" -H "Content-Type: application/json" \
  -d "{\"platform\":\"WEB\",\"token\":\"$FAKE2\"}" >/dev/null
TOMORROW=$(date -u -d "tomorrow 11:00" +%Y-%m-%dT%H:%M:%S.000Z 2>/dev/null || date -u -v +1d +%Y-%m-%dT11:00:00.000Z)
STD_PROD="dc1220fa-88e4-45ad-a649-d54c2f9b6c75"
ORD=$(curl -s -X POST "$API/orders" -H "Authorization: Bearer $CT" -H "Content-Type: application/json" \
  -d "{\"items\":[{\"productId\":\"$STD_PROD\",\"quantity\":1}],\"fulfillmentType\":\"PICKUP\",\"paymentMethod\":\"CASH\",\"scheduledFor\":\"$TOMORROW\"}")
OID=$(echo "$ORD" | grep -oE '"id":"[a-f0-9-]{36}"' | head -1 | grep -oE '[a-f0-9-]{36}')
[ -n "$OID" ] && pass "Customer placed order" || fail "place order"
# ACCEPTED transition → sendToUser → pushToUser
curl -s -X POST "$API/merchant/orders/$OID/transition" -H "Authorization: Bearer $MT" -H "Content-Type: application/json" \
  -d '{"toStatus":"ACCEPTED"}' >/dev/null
if wait_log "Push user=.* ok="; then
  pass "Order-status push fired: $(grep -oE 'Push user=[^ ]+ ok=[0-9]+/[0-9]+( pruned=[0-9]+)?' "$LOG" | tail -1)"
else
  fail "No order-status push log line"
fi

echo ""
echo "═══════════════════════════════════════════════════════"
printf "  \033[32mPASS:\033[0m %d   \033[31mFAIL:\033[0m %d\n" "$PASS" "$FAIL"
for e in "${ERRORS[@]}"; do printf "    - %s\n" "$e"; done
echo "═══════════════════════════════════════════════════════"
exit $FAIL
