#!/bin/bash
# Banan MERCHANT self-test — exercises every merchant CRUD surface +
# the full order lifecycle against a live backend. Creates entities,
# verifies them, then cleans up. Exit code = number of failures.
#
# Usage:  bash backend/scripts/selftest-merchant.sh

API=${API:-http://localhost:3000/api/v1}
PASS=0
FAIL=0
ERRORS=()

section() { echo ""; echo "▶ $1"; }
pass() { PASS=$((PASS+1)); printf "  \033[32m✓\033[0m %s\n" "$1"; }
fail() { FAIL=$((FAIL+1)); ERRORS+=("$1"); printf "  \033[31m✗\033[0m %s\n" "$1"; }

# Extract first JSON id that looks like a uuid, optionally anchored to a
# following key to avoid grabbing nested ids (e.g. "id":"…","storeId").
jid() { grep -oE "\"id\":\"[a-f0-9-]{36}\"$1" | head -1 | grep -oE '[a-f0-9-]{36}' | head -1; }

TOMORROW=$(date -u -d "tomorrow 11:00" +%Y-%m-%dT%H:%M:%S.000Z 2>/dev/null \
        || date -u -v +1d +%Y-%m-%dT11:00:00.000Z)
NEXTWEEK=$(date -u -d "+7 days" +%Y-%m-%dT00:00:00.000Z 2>/dev/null \
        || date -u -v +7d +%Y-%m-%dT00:00:00.000Z)
RND=$RANDOM

# ─────────────────────────────────────────────────────────────────────────
section "Auth"
MTOKEN=$(curl -s -X POST "$API/auth/login" -H "Content-Type: application/json" \
  -d '{"emailOrPhone":"merchant@banan.local","password":"banan123"}' \
  | grep -oE '"accessToken":"[^"]+"' | sed 's/"accessToken":"//;s/"$//')
CTOKEN=$(curl -s -X POST "$API/auth/login" -H "Content-Type: application/json" \
  -d '{"emailOrPhone":"customer@banan.local","password":"banan123"}' \
  | grep -oE '"accessToken":"[^"]+"' | sed 's/"accessToken":"//;s/"$//')
[ -n "$MTOKEN" ] && pass "Merchant login" || fail "Merchant login"
curl -s -H "Authorization: Bearer $MTOKEN" "$API/auth/me" \
  | grep -q 'MERCHANT_OWNER' && pass "Role = MERCHANT_OWNER" || fail "role check"

MH() { echo "-H"; echo "Authorization: Bearer $MTOKEN"; }
auth=(-H "Authorization: Bearer $MTOKEN" -H "Content-Type: application/json")

# A category id (needed for product create).
CAT_ID=$(curl -s "$API/categories" | grep -oE '"id":"[a-f0-9-]{36}"' | head -1 | grep -oE '[a-f0-9-]{36}')

# ─────────────────────────────────────────────────────────────────────────
section "Products CRUD"
PROD_CREATE=$(curl -s -X POST "${auth[@]}" "$API/products" -d "{
  \"categoryId\":\"$CAT_ID\",
  \"name\":\"Selftest Cake $RND\",
  \"slug\":\"selftest-cake-$RND\",
  \"description\":\"A product created by the merchant self-test.\",
  \"basePrice\":120000,
  \"images\":[\"https://picsum.photos/seed/selftest/800/600\"],
  \"variants\":[{\"size\":\"Default\",\"flavor\":\"Original\"}]
}")
PROD_ID=$(echo "$PROD_CREATE" | jid '')
[ -n "$PROD_ID" ] && pass "Create product ($PROD_ID)" \
  || fail "Create product: $(echo "$PROD_CREATE" | head -c 160)"

if [ -n "$PROD_ID" ]; then
  UPD=$(curl -s -X PATCH "${auth[@]}" "$API/products/$PROD_ID" \
    -d '{"basePrice":99000}')
  echo "$UPD" | grep -q '"basePrice":"99000"' \
    && pass "Update product basePrice" \
    || fail "Update product: $(echo "$UPD" | head -c 120)"

  DEL=$(curl -s -X DELETE "${auth[@]}" "$API/products/$PROD_ID")
  echo "$DEL" | grep -qE '"(deleted|archived)":true' \
    && pass "Delete product (outcome envelope)" \
    || fail "Delete product: $DEL"
fi

# ─────────────────────────────────────────────────────────────────────────
section "Collections CRUD"
COLL=$(curl -s -X POST "${auth[@]}" "$API/merchant/collections" -d "{
  \"name\":\"Selftest Collection $RND\",
  \"slug\":\"selftest-coll-$RND\",
  \"description\":\"temp\"
}")
COLL_ID=$(echo "$COLL" | jid '')
[ -n "$COLL_ID" ] && pass "Create collection" \
  || fail "Create collection: $(echo "$COLL" | head -c 160)"
if [ -n "$COLL_ID" ]; then
  curl -s -X PATCH "${auth[@]}" "$API/merchant/collections/$COLL_ID" \
    -d '{"description":"updated"}' | grep -q '"description":"updated"' \
    && pass "Update collection" || fail "Update collection"
  curl -s -X DELETE "${auth[@]}" "$API/merchant/collections/$COLL_ID" \
    -o /dev/null -w "%{http_code}" | grep -qE '^2' \
    && pass "Delete collection" || fail "Delete collection"
fi

# ─────────────────────────────────────────────────────────────────────────
section "Bundles CRUD (P2 #22)"
# Two real products to combo.
PA="dc1220fa-88e4-45ad-a649-d54c2f9b6c75"
PB="7e19226d-e44a-4e60-83d6-cd3f8459b2c6"
BUN=$(curl -s -X POST "${auth[@]}" "$API/merchant/bundles" -d "{
  \"name\":\"Selftest Combo $RND\",
  \"slug\":\"selftest-combo-$RND\",
  \"priceVnd\":150000,
  \"isActive\":true,
  \"isPinnedToHome\":false,
  \"items\":[{\"productId\":\"$PA\",\"quantity\":1},{\"productId\":\"$PB\",\"quantity\":2}]
}")
BUN_ID=$(echo "$BUN" | jid '')
[ -n "$BUN_ID" ] && pass "Create bundle" \
  || fail "Create bundle: $(echo "$BUN" | head -c 160)"
if [ -n "$BUN_ID" ]; then
  echo "$BUN" | grep -q '"quantity":2' && pass "Bundle items persisted" \
    || fail "Bundle items missing"
  UPB=$(curl -s -X PATCH "${auth[@]}" "$API/merchant/bundles/$BUN_ID" \
    -d '{"priceVnd":129000,"isPinnedToHome":true}')
  echo "$UPB" | grep -q '"priceVnd":129000' \
    && pass "Update bundle price" || fail "Update bundle"
  echo "$UPB" | grep -q '"isPinnedToHome":true' \
    && pass "Toggle pin-to-home" || fail "pin toggle"
  # Detail endpoint exposes savedVnd
  curl -s "$API/bundles/$BUN_ID" | grep -q '"savedVnd":' \
    && pass "Bundle detail has savedVnd" || fail "savedVnd missing"
  curl -s -X DELETE "${auth[@]}" "$API/merchant/bundles/$BUN_ID" \
    -o /dev/null -w "%{http_code}" | grep -qE '^2' \
    && pass "Delete bundle" || fail "Delete bundle"
fi
# Validation: empty items rejected
EMPTY_BUN=$(curl -s -X POST "${auth[@]}" "$API/merchant/bundles" \
  -d "{\"name\":\"Bad $RND\",\"slug\":\"bad-$RND\",\"priceVnd\":50000,\"items\":[]}")
echo "$EMPTY_BUN" | grep -q '"error"' \
  && pass "Bundle with empty items rejected" || fail "should reject empty items"

# ─────────────────────────────────────────────────────────────────────────
section "Banners CRUD"
BAN=$(curl -s -X POST "${auth[@]}" "$API/merchant/banners" -d "{
  \"imageUrl\":\"https://picsum.photos/seed/banner$RND/1200/400\",
  \"title\":\"Selftest banner\"
}")
BAN_ID=$(echo "$BAN" | jid '')
[ -n "$BAN_ID" ] && pass "Create banner" \
  || fail "Create banner: $(echo "$BAN" | head -c 160)"
if [ -n "$BAN_ID" ]; then
  curl -s -X PATCH "${auth[@]}" "$API/merchant/banners/$BAN_ID" \
    -d '{"isActive":false}' | grep -q '"isActive":false' \
    && pass "Update banner (deactivate)" || fail "Update banner"
  curl -s -X DELETE "${auth[@]}" "$API/merchant/banners/$BAN_ID" \
    -o /dev/null -w "%{http_code}" | grep -qE '^2' \
    && pass "Delete banner" || fail "Delete banner"
fi

# ─────────────────────────────────────────────────────────────────────────
section "Coupons CRUD"
COUP=$(curl -s -X POST "${auth[@]}" "$API/merchant/coupons" -d "{
  \"code\":\"SELFTEST$RND\",
  \"type\":\"PERCENT\",
  \"value\":10,
  \"startsAt\":\"$TOMORROW\",
  \"endsAt\":\"$NEXTWEEK\",
  \"perUserLimit\":1,
  \"label\":\"Selftest 10%\"
}")
COUP_ID=$(echo "$COUP" | jid '')
[ -n "$COUP_ID" ] && pass "Create coupon" \
  || fail "Create coupon: $(echo "$COUP" | head -c 160)"
if [ -n "$COUP_ID" ]; then
  curl -s -X PATCH "${auth[@]}" "$API/merchant/coupons/$COUP_ID" \
    -d '{"isActive":false}' | grep -q '"isActive":false' \
    && pass "Update coupon (deactivate)" || fail "Update coupon"
fi

# ─────────────────────────────────────────────────────────────────────────
section "Threads (posts)"
THR=$(curl -s -X POST "${auth[@]}" "$API/merchant/threads" -d "{
  \"title\":\"Selftest post $RND\",
  \"body\":\"Hello from the merchant self-test #selftest\"
}")
THR_ID=$(echo "$THR" | jid '')
[ -n "$THR_ID" ] && pass "Create thread/post" \
  || fail "Create thread: $(echo "$THR" | head -c 160)"
[ -n "$THR_ID" ] && curl -s -X DELETE "${auth[@]}" "$API/merchant/threads/$THR_ID" \
  -o /dev/null -w "%{http_code}" | grep -qE '^2' \
  && pass "Delete thread" || true

# ─────────────────────────────────────────────────────────────────────────
section "Store settings + pause"
curl -s -H "Authorization: Bearer $MTOKEN" "$API/merchant/store/settings" \
  | grep -qE '"isPaused"' && pass "Get store settings" || fail "Get settings"
# Pause then unpause
curl -s -X PATCH "${auth[@]}" "$API/merchant/store/settings" \
  -d '{"isPaused":true,"pauseReason":"selftest"}' \
  | grep -q '"isPaused":true' && pass "Pause store" || fail "Pause store"
curl -s -X PATCH "${auth[@]}" "$API/merchant/store/settings" \
  -d '{"isPaused":false}' | grep -q '"isPaused":false' \
  && pass "Unpause store" || fail "Unpause store"

# ─────────────────────────────────────────────────────────────────────────
section "Customers"
curl -s -H "Authorization: Bearer $MTOKEN" "$API/merchant/customers?perPage=3" \
  | grep -q '"data"' && pass "List customers" || fail "List customers"
CUST=$(curl -s -X POST "${auth[@]}" "$API/merchant/customers" \
  -d "{\"fullName\":\"Selftest Khach $RND\",\"phone\":\"098$RND$RND\"}")
echo "$CUST" | grep -q '"role":"CUSTOMER"' \
  && pass "Create customer" || fail "Create customer: $(echo "$CUST" | head -c 120)"

# ─────────────────────────────────────────────────────────────────────────
section "Reviews moderation"
curl -s -H "Authorization: Bearer $MTOKEN" "$API/merchant/reviews" \
  | grep -q '"data"' && pass "List reviews queue" || fail "reviews list"

# ─────────────────────────────────────────────────────────────────────────
section "Newsletter (merchant)"
curl -s -H "Authorization: Bearer $MTOKEN" "$API/merchant/newsletter" \
  | grep -q '"stats"' && pass "List subscribers + stats" || fail "newsletter list"
NL_INFO=$(curl -s -o /dev/null -w "%{http_code}|%{content_type}" \
  -H "Authorization: Bearer $MTOKEN" "$API/merchant/newsletter/export.csv")
echo "$NL_INFO" | grep -q "text/csv" && pass "Newsletter CSV export" \
  || fail "CSV export: $NL_INFO"

# ─────────────────────────────────────────────────────────────────────────
section "Reports + Excel"
RFROM=$(date -d "30 days ago" +%Y-%m-%d 2>/dev/null || date -v -30d +%Y-%m-%d)
RTO=$(date +%Y-%m-%d)
curl -s -H "Authorization: Bearer $MTOKEN" \
  "$API/merchant/reports/summary?from=$RFROM&to=$RTO" \
  | grep -q '"revenue":' && pass "Reports summary" || fail "reports summary"
XL=$(curl -s -o /dev/null -w "%{http_code}|%{size_download}" \
  -H "Authorization: Bearer $MTOKEN" \
  "$API/merchant/reports/export.xlsx?from=$RFROM&to=$RTO")
SZ=$(echo "$XL" | cut -d'|' -f2)
[ "$SZ" -gt 4000 ] && pass "XLSX export ($SZ bytes)" || fail "XLSX export ($XL)"

# ─────────────────────────────────────────────────────────────────────────
section "Display config + contact channels"
curl -s -X PATCH "${auth[@]}" "$API/display-config" \
  -d '{"contactPhone":"+84867540939","contactZaloOaId":"123456"}' \
  | grep -q '"contactZaloOaId":"123456"' \
  && pass "Set contact channels" || fail "set contact"
curl -s "$API/display-config" | grep -q '"contactPhone":"+84867540939"' \
  && pass "Public config reflects channels" || fail "public config"
# clear
curl -s -X PATCH "${auth[@]}" "$API/display-config" \
  -d '{"contactPhone":"","contactZaloOaId":""}' -o /dev/null

# ─────────────────────────────────────────────────────────────────────────
section "Order lifecycle (merchant transitions)"
# Customer places a scheduled PICKUP order.
OB="{\"items\":[{\"productId\":\"$PA\",\"quantity\":1}],\"fulfillmentType\":\"PICKUP\",\"paymentMethod\":\"CASH\",\"scheduledFor\":\"$TOMORROW\"}"
ORD=$(curl -s -X POST -H "Authorization: Bearer $CTOKEN" -H "Content-Type: application/json" \
  "$API/orders" -d "$OB")
ORD_ID=$(echo "$ORD" | jid '')
ORD_CODE=$(echo "$ORD" | grep -oE '"code":"BAN-[^"]+"' | head -1 | sed 's/"code":"//;s/"$//')
[ -n "$ORD_ID" ] && pass "Customer places order ($ORD_CODE)" \
  || fail "Place order: $(echo "$ORD" | head -c 160)"

transition() {
  local to="$1" label="$2"
  local resp
  resp=$(curl -s -X POST "${auth[@]}" "$API/merchant/orders/$ORD_ID/transition" \
    -d "{\"toStatus\":\"$to\"}")
  echo "$resp" | grep -q "\"status\":\"$to\"" \
    && pass "Transition → $label" \
    || fail "Transition $label: $(echo "$resp" | head -c 120)"
}

if [ -n "$ORD_ID" ]; then
  # Merchant sees it in the queue
  curl -s -H "Authorization: Bearer $MTOKEN" "$API/merchant/orders" \
    | grep -q "$ORD_CODE" && pass "Order in merchant queue" || fail "queue missing order"
  transition "ACCEPTED" "Đã nhận"
  transition "IN_PREPARATION" "Đang chuẩn bị"
  transition "READY_FOR_PICKUP" "Sẵn sàng lấy"
  transition "COMPLETED" "Hoàn tất"
  # Invalid transition from terminal state rejected
  BADTR=$(curl -s -X POST "${auth[@]}" "$API/merchant/orders/$ORD_ID/transition" \
    -d '{"toStatus":"PENDING"}')
  echo "$BADTR" | grep -qE 'ORDER_INVALID_TRANSITION|error' \
    && pass "Invalid transition from COMPLETED rejected" \
    || fail "should reject bad transition"
fi

# ─────────────────────────────────────────────────────────────────────────
section "Admin scope (cross-store)"
ATOKEN=$(curl -s -X POST "$API/auth/login" -H "Content-Type: application/json" \
  -d '{"emailOrPhone":"admin@banan.local","password":"banan123"}' \
  | grep -oE '"accessToken":"[^"]+"' | sed 's/"accessToken":"//;s/"$//')
curl -s -H "Authorization: Bearer $ATOKEN" "$API/merchant/orders" \
  | grep -q '"data"' && pass "Admin reads cross-store orders" || fail "admin orders"
curl -s -H "Authorization: Bearer $ATOKEN" "$API/merchant/bundles" \
  | grep -q '"data"' && pass "Admin reads bundles" || fail "admin bundles"

# Staff (non-owner) cannot create bundle (owner-only)
STOKEN=$(curl -s -X POST "$API/auth/login" -H "Content-Type: application/json" \
  -d '{"emailOrPhone":"kitchen@banan.local","password":"banan123"}' \
  | grep -oE '"accessToken":"[^"]+"' | sed 's/"accessToken":"//;s/"$//')
KCODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
  -H "Authorization: Bearer $STOKEN" -H "Content-Type: application/json" \
  "$API/merchant/bundles" -d '{"name":"x","slug":"x","priceVnd":1000,"items":[]}')
[ "$KCODE" = "403" ] && pass "Kitchen role forbidden from bundle create (403)" \
  || fail "kitchen bundle create = $KCODE (want 403)"

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
