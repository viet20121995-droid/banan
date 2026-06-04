#!/bin/bash
# End-to-end test: actually CREATE orders and verify the persisted
# deliveryFee matches the ward-equality rule (not just /delivery-quote).
#
# Covers 4 scenarios:
#   1. Standard, same ward      → expect 0₫
#   2. Standard, other ward     → expect 30,000₫
#   3. Birthday, same ward      → expect 30,000₫
#   4. Birthday, other ward     → expect 70,000₫
#
# Plus 1 pickup case to confirm PICKUP has no delivery fee.

set -e

API=http://localhost:3000/api/v1

# ── 1. Login as the seeded customer ──────────────────────────────────
echo "▶ Login as customer@banan.local"
LOGIN=$(curl -s -X POST "$API/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"emailOrPhone":"customer@banan.local","password":"banan123"}')
TOKEN=$(echo "$LOGIN" | grep -oE '"accessToken":"[^"]+"' | sed 's/"accessToken":"//;s/"$//')
if [ -z "$TOKEN" ]; then
  echo "ERR: login failed — $LOGIN" >&2
  exit 1
fi
echo "  ✓ got accessToken"

# ── 2. Pick one standard product (cookie choux) + one birthday cake ──
PRODUCTS=$(curl -s "$API/products?perPage=50")
STD_PROD=$(echo "$PRODUCTS" \
  | grep -oE '"id":"[^"]+","storeId":"[^"]+","categoryId":"[^"]+","name":"Original Cookie Choux"' \
  | head -1 | grep -oE '"id":"[^"]+"' | head -1 | sed 's/"id":"//;s/"$//')
BDAY_PROD=$(echo "$PRODUCTS" \
  | grep -oE '"id":"[^"]+","storeId":"[^"]+","categoryId":"[^"]+","name":"Signature Strawberry Cake"' \
  | head -1 | grep -oE '"id":"[^"]+"' | head -1 | sed 's/"id":"//;s/"$//')

if [ -z "$STD_PROD" ] || [ -z "$BDAY_PROD" ]; then
  echo "ERR: products not found (std=$STD_PROD bday=$BDAY_PROD)" >&2
  exit 1
fi
echo "  ✓ std product:   $STD_PROD"
echo "  ✓ bday product:  $BDAY_PROD"

# ── 3. Helper to place an order and extract fee / routed store ───────
SAME_WARD="sai-gon"      # LTT store ward → same-ward case
OTHER_WARD="binh-thanh"  # Far from any store → other-ward case

place_order() {
  local label="$1" wardCode="$2" productId="$3" fulfillment="$4"
  local body
  # Schedule both pickup and delivery 4h out so the store's defaultLeadHours
  # (2h) and any product lead-time bound is satisfied.
  local scheduledFor
  if command -v gdate >/dev/null 2>&1; then
    scheduledFor=$(gdate -u -d '+4 hours' +%Y-%m-%dT%H:%M:%S.000Z)
  else
    scheduledFor=$(date -u -d '+4 hours' +%Y-%m-%dT%H:%M:%S.000Z 2>/dev/null \
      || date -u -v+4H +%Y-%m-%dT%H:%M:%S.000Z)
  fi

  if [ "$fulfillment" = "DELIVERY" ]; then
    body=$(cat <<EOF
{
  "items": [{"productId":"$productId","quantity":1}],
  "fulfillmentType": "DELIVERY",
  "paymentMethod": "VNPAY",
  "scheduledFor": "$scheduledFor",
  "address": {
    "recipient": "Test Customer",
    "phone": "0900111222",
    "line1": "123 Test Street",
    "city": "Thành phố Hồ Chí Minh",
    "wardCode": "$wardCode"
  },
  "notes": "$label"
}
EOF
)
  else
    body=$(cat <<EOF
{
  "items": [{"productId":"$productId","quantity":1}],
  "fulfillmentType": "PICKUP",
  "paymentMethod": "CASH",
  "scheduledFor": "$scheduledFor",
  "notes": "$label"
}
EOF
)
  fi

  local resp
  resp=$(curl -s -X POST "$API/orders" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "$body")

  local code         fee            store_name      total           subtotal
  # Match the order code (e.g. BAN-2026-7Q3K2X), not the error envelope's "code" field.
  code=$(echo "$resp"     | grep -oE '"code":"BAN-[^"]+"'   | head -1 | sed 's/"code":"//;s/"$//')
  fee=$(echo "$resp"      | grep -oE '"deliveryFee":"[^"]+"' | head -1 | sed 's/"deliveryFee":"//;s/"$//')
  subtotal=$(echo "$resp" | grep -oE '"subtotal":"[^"]+"'    | head -1 | sed 's/"subtotal":"//;s/"$//')
  total=$(echo "$resp"    | grep -oE '"total":"[^"]+"'       | head -1 | sed 's/"total":"//;s/"$//')
  store_name=$(echo "$resp" \
    | grep -oE '"store":\{"id":"[^"]+","name":"[^"]+"' \
    | sed 's/.*"name":"//;s/"$//;s/Banan – //')

  if [ -z "$code" ]; then
    local err
    err=$(echo "$resp" | grep -oE '"message":"[^"]*"' | head -1 | sed 's/"message":"//;s/"$//')
    printf "  ✗ %-38s ERROR: %s\n" "$label" "${err:-$resp}" >&2
    echo ""
    return 0
  fi

  printf "  ✓ %-38s code=%s  ward=%-13s  store=%-22s  subtotal=%-8s  fee=%-8s  total=%s\n" \
    "$label" "$code" "${wardCode:-pickup}" "$store_name" "$subtotal" "$fee" "$total" >&2
  # deliveryFee is a Decimal string like "0" or "30000" — strip a trailing ".00" if Prisma renders it that way.
  echo "${fee%.*}"
}

# ── 4. Run the 5 scenarios ───────────────────────────────────────────
echo ""
echo "▶ Placing orders…"
echo ""

FEE1=$(place_order "1. Std + same ward (sai-gon)"     "$SAME_WARD"  "$STD_PROD"  "DELIVERY")
FEE2=$(place_order "2. Std + other ward (binh-thanh)" "$OTHER_WARD" "$STD_PROD"  "DELIVERY")
FEE3=$(place_order "3. Bday + same ward (sai-gon)"    "$SAME_WARD"  "$BDAY_PROD" "DELIVERY")
FEE4=$(place_order "4. Bday + other ward (binh-thanh)" "$OTHER_WARD" "$BDAY_PROD" "DELIVERY")
FEE5=$(place_order "5. Pickup (no delivery fee)"      ""            "$STD_PROD"  "PICKUP")

# ── 5. Verify each fee matches the expected ward-equality rule ───────
echo ""
echo "▶ Verifying fees…"

check() {
  local label="$1" got="$2" want="$3"
  if [ "$got" = "$want" ]; then
    printf "  ✓ %-40s expected %-8s got %s\n" "$label" "$want" "$got"
  else
    printf "  ✗ %-40s expected %-8s got %s   <<< MISMATCH\n" "$label" "$want" "$got"
  fi
}

check "Std same-ward"   "$FEE1" "0"
check "Std other-ward"  "$FEE2" "30000"
check "Bday same-ward"  "$FEE3" "30000"
check "Bday other-ward" "$FEE4" "70000"
check "Pickup"          "$FEE5" "0"

echo ""
echo "Done."
