#!/bin/bash
# Banan ORDER-LIFECYCLE self-test — exercises every ordering scenario,
# product type, and the two preparation paths:
#   • làm tại quầy (counter)  : merchant ACCEPTED → IN_PREPARATION → ready
#   • đẩy qua kitchen (central): transfer-to-kitchen → kanban → dispatch
# against a live backend. Exit code = number of failures.
#
# Usage:  bash backend/scripts/selftest-orders.sh
#   or:   API=https://api.banan.com/api/v1 bash backend/scripts/selftest-orders.sh

API=${API:-http://localhost:3000/api/v1}
PASS=0
FAIL=0
ERRORS=()

section() { echo ""; echo "▶ $1"; }
pass() { PASS=$((PASS+1)); printf "  \033[32m✓\033[0m %s\n" "$1"; }
fail() { FAIL=$((FAIL+1)); ERRORS+=("$1"); printf "  \033[31m✗\033[0m %s\n" "$1"; }

# Assert the response body contains a needle; else fail with a snippet.
want() {  # want <label> <body> <needle>
  if echo "$2" | grep -q "$3"; then pass "$1"; else fail "$1  (want '$3' — got: $(echo "$2" | head -c 160))"; fi
}
# Assert the response body does NOT contain a needle.
wantnot() { if echo "$2" | grep -q "$3"; then fail "$1  (unexpected '$3')"; else pass "$1"; fi; }

# First order id in a create/transition response (order is serialised first).
oid() { echo "$1" | grep -oE '"id":"[a-f0-9-]{36}"' | head -1 | grep -oE '[a-f0-9-]{36}'; }
ocode() { echo "$1" | grep -oE '"code":"BAN-[^"]+"' | head -1 | sed 's/"code":"//;s/"$//'; }

TOMORROW=$(date -u -d "tomorrow 11:00" +%Y-%m-%dT%H:%M:%S.000Z 2>/dev/null \
        || date -u -v +1d +%Y-%m-%dT11:00:00.000Z)
RND=$RANDOM

# Seed product / variant IDs (stable across re-seeds — keyed by slug).
STD_PROD="dc1220fa-88e4-45ad-a649-d54c2f9b6c75"   # Original Cookie Choux (standard)
BDAY_PROD="7e19226d-e44a-4e60-83d6-cd3f8459b2c6"  # Signature Strawberry Cake (birthday)
MAC5_PROD="70168e01-9714-46d8-83d1-33cd0e653fe3"  # Set of 5 Macarons (flavour set)
MAC5_VAR="9a8b2b90-0864-42f0-8858-cf374b52438a"

# ─────────────────────────────────────────────────────────────────────────
section "Auth"
login() { curl -s -X POST "$API/auth/login" -H "Content-Type: application/json" \
  -d "{\"emailOrPhone\":\"$1\",\"password\":\"banan123\"}" \
  | grep -oE '"accessToken":"[^"]+"' | sed 's/"accessToken":"//;s/"$//'; }
CTOKEN=$(login customer@banan.local)
MTOKEN=$(login merchant@banan.local)
ATOKEN=$(login admin@banan.local)
KTOKEN=$(login kitchen@banan.local)
[ -n "$CTOKEN" ] && pass "Customer login" || fail "Customer login"
[ -n "$MTOKEN" ] && pass "Merchant login" || fail "Merchant login"
[ -n "$KTOKEN" ] && pass "Kitchen login"  || fail "Kitchen login"

cauth=(-H "Authorization: Bearer $CTOKEN" -H "Content-Type: application/json")
mauth=(-H "Authorization: Bearer $MTOKEN" -H "Content-Type: application/json")
kauth=(-H "Authorization: Bearer $KTOKEN" -H "Content-Type: application/json")

# Place an order as the logged-in customer.
place_c() { curl -s -X POST "${cauth[@]}" "$API/orders" -d "$1"; }
# Merchant lifecycle transition.
mtrans() { curl -s -X POST "${mauth[@]}" "$API/merchant/orders/$1/transition" -d "{\"toStatus\":\"$2\"}"; }
# Kitchen kanban transition.
ktrans() { curl -s -X POST "${kauth[@]}" "$API/kitchen/orders/$1/transition" -d "{\"toKitchenStatus\":\"$2\"}"; }

# ═════════════════════════════════════════════════════════════════════════
section "1 · Order scenarios by product / payment / fulfillment"

# 1.1 Standard product, single line, PICKUP + CASH
R=$(place_c "{\"items\":[{\"productId\":\"$STD_PROD\",\"quantity\":2}],\"fulfillmentType\":\"PICKUP\",\"paymentMethod\":\"CASH\",\"scheduledFor\":\"$TOMORROW\"}")
want "Standard PICKUP/CASH order created" "$R" '"code":"BAN-'
want "  → starts at PENDING" "$R" '"status":"PENDING"'

# 1.2 Birthday cake WITH personalization
R=$(place_c "{\"items\":[{\"productId\":\"$BDAY_PROD\",\"quantity\":1,\"personalization\":{\"textOnCake\":\"Chuc mung sinh nhat An\",\"candleCount\":7,\"note\":\"Ribbon vang\"}}],\"fulfillmentType\":\"PICKUP\",\"paymentMethod\":\"CASH\",\"scheduledFor\":\"$TOMORROW\"}")
want "Birthday cake + personalization created" "$R" '"code":"BAN-'
want "  → textOnCake persisted" "$R" '"textOnCake"'
want "  → candleCount persisted" "$R" '"candleCount":7'

# 1.3 Macaron Set of 5 — valid flavour composition (sum == 5)
R=$(place_c "{\"items\":[{\"productId\":\"$MAC5_PROD\",\"variantId\":\"$MAC5_VAR\",\"quantity\":1,\"personalization\":{\"flavors\":{\"Jasmine\":2,\"Lemon\":2,\"Earl Grey\":1}}}],\"fulfillmentType\":\"PICKUP\",\"paymentMethod\":\"CASH\",\"scheduledFor\":\"$TOMORROW\"}")
want "Macaron Set of 5 (valid 2+2+1) created" "$R" '"code":"BAN-'
want "  → flavours persisted" "$R" '"flavors"'

# 1.4 Macaron set — wrong count (sum == 3) rejected
R=$(place_c "{\"items\":[{\"productId\":\"$MAC5_PROD\",\"variantId\":\"$MAC5_VAR\",\"quantity\":1,\"personalization\":{\"flavors\":{\"Jasmine\":2,\"Lemon\":1}}}],\"fulfillmentType\":\"PICKUP\",\"paymentMethod\":\"CASH\",\"scheduledFor\":\"$TOMORROW\"}")
want "Macaron wrong count rejected (FLAVOR_COUNT_MISMATCH)" "$R" 'FLAVOR_COUNT_MISMATCH'

# 1.5 Macaron set — unknown flavour rejected
R=$(place_c "{\"items\":[{\"productId\":\"$MAC5_PROD\",\"variantId\":\"$MAC5_VAR\",\"quantity\":1,\"personalization\":{\"flavors\":{\"Jasmine\":2,\"Lemon\":2,\"UnicornDust\":1}}}],\"fulfillmentType\":\"PICKUP\",\"paymentMethod\":\"CASH\",\"scheduledFor\":\"$TOMORROW\"}")
want "Macaron unknown flavour rejected (FLAVOR_UNKNOWN)" "$R" 'FLAVOR_UNKNOWN'

# 1.6 Multi-item order (standard + birthday) in one cart
R=$(place_c "{\"items\":[{\"productId\":\"$STD_PROD\",\"quantity\":1},{\"productId\":\"$BDAY_PROD\",\"quantity\":1}],\"fulfillmentType\":\"PICKUP\",\"paymentMethod\":\"CASH\",\"scheduledFor\":\"$TOMORROW\"}")
want "Multi-item order created" "$R" '"code":"BAN-'
NLINES=$(echo "$R" | grep -oE '"productName":' | wc -l)
[ "$NLINES" -eq 2 ] && pass "  → 2 line items persisted" || fail "  → expected 2 lines, got $NLINES"

# 1.7 Guest order (no auth — inline name/phone)
R=$(curl -s -X POST -H "Content-Type: application/json" "$API/orders" \
  -d "{\"items\":[{\"productId\":\"$STD_PROD\",\"quantity\":1}],\"fulfillmentType\":\"PICKUP\",\"paymentMethod\":\"CASH\",\"scheduledFor\":\"$TOMORROW\",\"guestFullName\":\"Khach Vang Lai $RND\",\"guestPhone\":\"098${RND}11\"}")
want "Guest order created (no login)" "$R" '"code":"BAN-'

# 1.8 DELIVERY order (VNPAY + address) — order still created even if the
#     provider is unconfigured (returns a configurationError, not a failure).
DELIV_BODY="{\"items\":[{\"productId\":\"$STD_PROD\",\"quantity\":1}],\"fulfillmentType\":\"DELIVERY\",\"paymentMethod\":\"VNPAY\",\"address\":{\"recipient\":\"Nguyen Van A\",\"phone\":\"0900000000\",\"line1\":\"12 Le Loi\",\"city\":\"HCMC\",\"wardCode\":\"sai-gon\"},\"scheduledFor\":\"$TOMORROW\"}"
R=$(place_c "$DELIV_BODY")
want "DELIVERY order (VNPAY) created" "$R" '"code":"BAN-'
want "  → fulfillmentType DELIVERY" "$R" '"fulfillmentType":"DELIVERY"'

# 1.9 DELIVERY + CASH accepted — COD is enabled for delivery (Vietnam norm)
R=$(place_c "{\"items\":[{\"productId\":\"$STD_PROD\",\"quantity\":1}],\"fulfillmentType\":\"DELIVERY\",\"paymentMethod\":\"CASH\",\"address\":{\"recipient\":\"A\",\"phone\":\"0900000000\",\"line1\":\"12 Le Loi\",\"city\":\"HCMC\",\"wardCode\":\"sai-gon\"},\"scheduledFor\":\"$TOMORROW\"}")
want "DELIVERY + CASH accepted (COD)" "$R" '"code":"BAN-'

# 1.10 DELIVERY without address rejected
R=$(place_c "{\"items\":[{\"productId\":\"$STD_PROD\",\"quantity\":1}],\"fulfillmentType\":\"DELIVERY\",\"paymentMethod\":\"VNPAY\",\"scheduledFor\":\"$TOMORROW\"}")
want "DELIVERY without address rejected (ADDRESS_REQUIRED)" "$R" 'ADDRESS_REQUIRED'

# ═════════════════════════════════════════════════════════════════════════
section "2 · Làm tại quầy (counter prep — never leaves the store)"

# 2.1 PICKUP counter path
R=$(place_c "{\"items\":[{\"productId\":\"$STD_PROD\",\"quantity\":1}],\"fulfillmentType\":\"PICKUP\",\"paymentMethod\":\"CASH\",\"scheduledFor\":\"$TOMORROW\"}")
OID=$(oid "$R"); OCODE=$(ocode "$R")
[ -n "$OID" ] && pass "Counter PICKUP order placed ($OCODE)" || fail "place counter pickup"
want "  merchant queue shows it" "$(curl -s "${mauth[@]}" "$API/merchant/orders")" "$OCODE"
want "  → ACCEPTED"        "$(mtrans "$OID" ACCEPTED)"        '"status":"ACCEPTED"'
want "  → IN_PREPARATION (quầy)" "$(mtrans "$OID" IN_PREPARATION)" '"status":"IN_PREPARATION"'
want "  → READY_FOR_PICKUP" "$(mtrans "$OID" READY_FOR_PICKUP)" '"status":"READY_FOR_PICKUP"'
want "  → COMPLETED"       "$(mtrans "$OID" COMPLETED)"       '"status":"COMPLETED"'

# 2.2 DELIVERY counter path (IN_PREPARATION → DELIVERING → COMPLETED)
R=$(place_c "$DELIV_BODY")
OID=$(oid "$R"); OCODE=$(ocode "$R")
[ -n "$OID" ] && pass "Counter DELIVERY order placed ($OCODE)" || fail "place counter delivery"
want "  → ACCEPTED"        "$(mtrans "$OID" ACCEPTED)"        '"status":"ACCEPTED"'
want "  → IN_PREPARATION"  "$(mtrans "$OID" IN_PREPARATION)"  '"status":"IN_PREPARATION"'
want "  → DELIVERING"      "$(mtrans "$OID" DELIVERING)"      '"status":"DELIVERING"'
want "  → COMPLETED"       "$(mtrans "$OID" COMPLETED)"       '"status":"COMPLETED"'

# ═════════════════════════════════════════════════════════════════════════
section "3 · Đẩy đơn qua kitchen (central-kitchen prep)"

# 3.1 PICKUP through the kitchen
R=$(place_c "{\"items\":[{\"productId\":\"$BDAY_PROD\",\"quantity\":1,\"personalization\":{\"textOnCake\":\"Happy\",\"candleCount\":3}}],\"fulfillmentType\":\"PICKUP\",\"paymentMethod\":\"CASH\",\"scheduledFor\":\"$TOMORROW\"}")
OID=$(oid "$R"); OCODE=$(ocode "$R")
[ -n "$OID" ] && pass "Kitchen-bound PICKUP order placed ($OCODE)" || fail "place kitchen pickup"
want "  → ACCEPTED" "$(mtrans "$OID" ACCEPTED)" '"status":"ACCEPTED"'
TK=$(curl -s -X POST "${mauth[@]}" "$API/merchant/orders/$OID/transfer-to-kitchen" -d '{"note":"selftest"}')
want "  transfer-to-kitchen → SENT_TO_KITCHEN" "$TK" '"status":"SENT_TO_KITCHEN"'
want "  → kitchenStatus PENDING_ACK"           "$TK" '"kitchenStatus":"PENDING_ACK"'
want "  kitchen queue shows it" "$(curl -s "${kauth[@]}" "$API/kitchen/orders")" "$OCODE"
want "  kanban PENDING_ACK → PREPARING"   "$(ktrans "$OID" PREPARING)"      '"kitchenStatus":"PREPARING"'
# 3.2 invalid skip (PREPARING → PENDING_ACK) rejected
want "  invalid kanban jump rejected"     "$(ktrans "$OID" PENDING_ACK)"    'KITCHEN_INVALID_TRANSITION'
want "  kanban PREPARING → READY_DISPATCH" "$(ktrans "$OID" READY_DISPATCH)" '"kitchenStatus":"READY_DISPATCH"'
DSP=$(curl -s -X POST "${kauth[@]}" "$API/kitchen/orders/$OID/dispatch")
want "  dispatch → READY_FOR_PICKUP" "$DSP" '"status":"READY_FOR_PICKUP"'
want "  merchant → COMPLETED" "$(mtrans "$OID" COMPLETED)" '"status":"COMPLETED"'

# 3.3 DELIVERY through the kitchen → dispatch must land on DELIVERING
R=$(place_c "$DELIV_BODY")
OID=$(oid "$R"); OCODE=$(ocode "$R")
[ -n "$OID" ] && pass "Kitchen-bound DELIVERY order placed ($OCODE)" || fail "place kitchen delivery"
mtrans "$OID" ACCEPTED >/dev/null
curl -s -X POST "${mauth[@]}" "$API/merchant/orders/$OID/transfer-to-kitchen" -d '{}' >/dev/null
ktrans "$OID" PREPARING >/dev/null
ktrans "$OID" READY_DISPATCH >/dev/null
DSP=$(curl -s -X POST "${kauth[@]}" "$API/kitchen/orders/$OID/dispatch")
want "  delivery dispatch → DELIVERING" "$DSP" '"status":"DELIVERING"'
want "  → COMPLETED" "$(mtrans "$OID" COMPLETED)" '"status":"COMPLETED"'

# 3.4 Kitchen scope — a foreign kitchen cannot dispatch (use a fresh order)
R=$(place_c "{\"items\":[{\"productId\":\"$STD_PROD\",\"quantity\":1}],\"fulfillmentType\":\"PICKUP\",\"paymentMethod\":\"CASH\",\"scheduledFor\":\"$TOMORROW\"}")
OID=$(oid "$R")
mtrans "$OID" ACCEPTED >/dev/null
# Transfer before kitchen, then try to transition with the CUSTOMER token (no kitchen role).
curl -s -X POST "${mauth[@]}" "$API/merchant/orders/$OID/transfer-to-kitchen" -d '{}' >/dev/null
NOAUTH=$(curl -s -o /dev/null -w "%{http_code}" -X POST "${cauth[@]}" "$API/kitchen/orders/$OID/transition" -d '{"toKitchenStatus":"PREPARING"}')
[ "$NOAUTH" = "403" ] && pass "  customer blocked from kitchen transition (403)" || fail "  customer kitchen transition = $NOAUTH (want 403)"

# ═════════════════════════════════════════════════════════════════════════
section "4 · Cancellation + guards"

# 4.1 Customer cancels a pending order
R=$(place_c "{\"items\":[{\"productId\":\"$STD_PROD\",\"quantity\":1}],\"fulfillmentType\":\"PICKUP\",\"paymentMethod\":\"CASH\",\"scheduledFor\":\"$TOMORROW\"}")
OID=$(oid "$R")
CAN=$(curl -s -X POST "${cauth[@]}" "$API/orders/$OID/cancel" -d '{"reason":"Doi y"}')
want "Customer cancels pending order → CANCELLED" "$CAN" '"status":"CANCELLED"'

# 4.2 No transition out of a terminal state
want "Transition from CANCELLED rejected" "$(mtrans "$OID" ACCEPTED)" 'ORDER_INVALID_TRANSITION'

# 4.3 Transfer-to-kitchen from PENDING (not yet accepted) rejected
R=$(place_c "{\"items\":[{\"productId\":\"$STD_PROD\",\"quantity\":1}],\"fulfillmentType\":\"PICKUP\",\"paymentMethod\":\"CASH\",\"scheduledFor\":\"$TOMORROW\"}")
OID=$(oid "$R")
TKBAD=$(curl -s -X POST "${mauth[@]}" "$API/merchant/orders/$OID/transfer-to-kitchen" -d '{}')
want "Transfer-to-kitchen from PENDING rejected" "$TKBAD" 'ORDER_INVALID_TRANSITION'
# tidy: cancel it so it doesn't linger in the queue
curl -s -X POST "${cauth[@]}" "$API/orders/$OID/cancel" -d '{"reason":"cleanup"}' >/dev/null

# ─────────────────────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════"
printf "  \033[32mPASS:\033[0m %d   \033[31mFAIL:\033[0m %d\n" "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo "  Failed checks:"
  for e in "${ERRORS[@]}"; do printf "    - %s\n" "$e"; done
fi
echo "═══════════════════════════════════════════════════════"
exit $FAIL
