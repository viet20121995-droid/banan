#!/bin/bash
# Banan API self-test — walks every major flow against a live backend
# at $API (default localhost:3000). Exit code = number of failures.
#
# Usage:  bash backend/scripts/selftest.sh
#   or:   API=https://api.banan.com/api/v1 bash backend/scripts/selftest.sh

API=${API:-http://localhost:3000/api/v1}

PASS=0
FAIL=0
ERRORS=()

section() { echo ""; echo "▶ $1"; }
pass() { PASS=$((PASS+1)); printf "  \033[32m✓\033[0m %s\n" "$1"; }
fail() { FAIL=$((FAIL+1)); ERRORS+=("$1"); printf "  \033[31m✗\033[0m %s\n" "$1"; }

# Assert HTTP status is 2xx for a GET
expect_get() {
  local label="$1" url="$2" auth="$3"
  local code
  if [ -n "$auth" ]; then
    code=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $auth" "$url")
  else
    code=$(curl -s -o /dev/null -w "%{http_code}" "$url")
  fi
  if [ "$code" -ge 200 ] && [ "$code" -lt 300 ]; then
    pass "$label  [$code]"
  else
    fail "$label  [$code]"
  fi
}

# Assert response body contains a key
expect_get_contains() {
  local label="$1" url="$2" auth="$3" needle="$4"
  local body
  if [ -n "$auth" ]; then
    body=$(curl -s -H "Authorization: Bearer $auth" "$url")
  else
    body=$(curl -s "$url")
  fi
  if echo "$body" | grep -q "$needle"; then
    pass "$label"
  else
    fail "$label  (missing '$needle')"
  fi
}

# ─────────────────────────────────────────────────────────────────────────
section "Health"
expect_get "Backend health"               "$API/health"
expect_get_contains "Health says ok"      "$API/health" "" '"ok":true'

# ─────────────────────────────────────────────────────────────────────────
section "Auth"
CUSTOMER_TOKEN=$(curl -s -X POST "$API/auth/login" -H "Content-Type: application/json" \
  -d '{"emailOrPhone":"customer@banan.local","password":"banan123"}' \
  | grep -oE '"accessToken":"[^"]+"' | sed 's/"accessToken":"//;s/"$//')
MERCHANT_TOKEN=$(curl -s -X POST "$API/auth/login" -H "Content-Type: application/json" \
  -d '{"emailOrPhone":"merchant@banan.local","password":"banan123"}' \
  | grep -oE '"accessToken":"[^"]+"' | sed 's/"accessToken":"//;s/"$//')
ADMIN_TOKEN=$(curl -s -X POST "$API/auth/login" -H "Content-Type: application/json" \
  -d '{"emailOrPhone":"admin@banan.local","password":"banan123"}' \
  | grep -oE '"accessToken":"[^"]+"' | sed 's/"accessToken":"//;s/"$//')
KITCHEN_TOKEN=$(curl -s -X POST "$API/auth/login" -H "Content-Type: application/json" \
  -d '{"emailOrPhone":"kitchen@banan.local","password":"banan123"}' \
  | grep -oE '"accessToken":"[^"]+"' | sed 's/"accessToken":"//;s/"$//')

[ -n "$CUSTOMER_TOKEN" ] && pass "Customer login"           || fail "Customer login"
[ -n "$MERCHANT_TOKEN" ] && pass "Merchant login"           || fail "Merchant login"
[ -n "$ADMIN_TOKEN" ]    && pass "Admin login"              || fail "Admin login"
[ -n "$KITCHEN_TOKEN" ]  && pass "Kitchen login"            || fail "Kitchen login"

expect_get_contains "Wrong password rejected (401)" \
  "$API/auth/me" "wrong-token-here" '"error"' || true
# /auth/me with valid token
curl -s -H "Authorization: Bearer $CUSTOMER_TOKEN" "$API/auth/me" \
  | grep -q '"role":"CUSTOMER"' && pass "Customer /auth/me role" || fail "Customer /auth/me"

# ─────────────────────────────────────────────────────────────────────────
section "Catalog (public)"
expect_get        "Products list"              "$API/products?perPage=5"
expect_get_contains "Products has averageRating" "$API/products?perPage=1" "" '"averageRating"'
expect_get_contains "Products has reviewCount"   "$API/products?perPage=1" "" '"reviewCount"'

# Search
SEARCH_HITS=$(curl -s "$API/products?q=mochi&perPage=20" | grep -oE '"id":' | wc -l)
[ "$SEARCH_HITS" -gt 0 ] && pass "Search q=mochi returned $SEARCH_HITS hits" || fail "Search q=mochi empty"

# Category filter
CAT_ID=$(curl -s "$API/categories" | grep -oE '"id":"[a-f0-9-]+"' | head -1 | sed 's/"id":"//;s/"$//')
expect_get "Products by categoryId"          "$API/products?categoryId=$CAT_ID&perPage=5"

# Single product detail
PROD_ID=$(curl -s "$API/products?perPage=1" | grep -oE '"id":"[a-f0-9-]+"' | head -1 | sed 's/"id":"//;s/"$//')
expect_get "Single product detail"             "$API/products/$PROD_ID"

# Categories / collections / banners
expect_get "Categories list"                 "$API/categories"
expect_get "Home collections"                "$API/collections/home"
expect_get "Banners"                         "$API/banners"
expect_get "Promo popup"                     "$API/promo-popup"

# Geo
expect_get "HCMC wards (geo)"                "$API/geo/hcm-wards"
WARD_CNT=$(curl -s "$API/geo/hcm-wards" | grep -oE '"code":"[^"]+"' | wc -l)
[ "$WARD_CNT" -ge 40 ] && pass "Geo wards count = $WARD_CNT (≥40)" || fail "Geo wards too few ($WARD_CNT)"

# Delivery quote
DQ_FEE=$(curl -s -X POST "$API/geo/delivery-quote" -H "Content-Type: application/json" \
  -d '{"wardCode":"sai-gon","productIds":[]}' \
  | grep -oE '"totalVnd":[0-9]+' | head -1 | sed 's/"totalVnd"://')
[ "$DQ_FEE" = "0" ] && pass "Delivery quote sai-gon = 0₫ (same ward)" || fail "Delivery quote sai-gon = $DQ_FEE"

# ─────────────────────────────────────────────────────────────────────────
section "Reviews (P0)"
expect_get        "Public reviews for product"  "$API/reviews/product/$PROD_ID"
expect_get_contains "Reviews has summary"       "$API/reviews/product/$PROD_ID" "" '"summary"'
expect_get        "My reviews"                  "$API/reviews/mine" "$CUSTOMER_TOKEN"
expect_get        "Merchant reviews moderation queue"  "$API/merchant/reviews" "$MERCHANT_TOKEN"

# ─────────────────────────────────────────────────────────────────────────
section "Wishlist (P0)"
WP="7e19226d-e44a-4e60-83d6-cd3f8459b2c6"  # Signature Strawberry Cake
curl -s -X POST -H "Authorization: Bearer $CUSTOMER_TOKEN" "$API/wishlist/$WP" -o /dev/null -w "%{http_code}\n" \
  | grep -qE '^2' && pass "Add to wishlist" || fail "Add to wishlist"
curl -s -H "Authorization: Bearer $CUSTOMER_TOKEN" "$API/wishlist/ids" \
  | grep -q "$WP" && pass "Wishlist ids contains product" || fail "Wishlist ids missing"
expect_get "Wishlist full list"               "$API/wishlist" "$CUSTOMER_TOKEN"
curl -s -X DELETE -H "Authorization: Bearer $CUSTOMER_TOKEN" "$API/wishlist/$WP" -o /dev/null -w "%{http_code}\n" \
  | grep -qE '^2' && pass "Remove from wishlist" || fail "Remove from wishlist"

# ─────────────────────────────────────────────────────────────────────────
section "Address book"
expect_get "Customer addresses list"          "$API/addresses" "$CUSTOMER_TOKEN"

# ─────────────────────────────────────────────────────────────────────────
section "Loyalty + coupons"
expect_get "My loyalty events"                "$API/me/loyalty" "$CUSTOMER_TOKEN"
expect_get "Merchant coupons list"            "$API/merchant/coupons" "$MERCHANT_TOKEN"

# ─────────────────────────────────────────────────────────────────────────
section "Notifications"
expect_get "Customer notifications"           "$API/me/notifications" "$CUSTOMER_TOKEN"

# ─────────────────────────────────────────────────────────────────────────
section "Order flow (end-to-end)"
# Standard order, scheduled tomorrow 11:00 UTC (avoids lead-time rejection)
TOMORROW=$(date -u -d "tomorrow 11:00" +%Y-%m-%dT%H:%M:%S.000Z 2>/dev/null \
        || date -u -v +1d +%Y-%m-%dT11:00:00.000Z)
STD_PROD="dc1220fa-88e4-45ad-a649-d54c2f9b6c75"   # Original Cookie Choux
BDAY_PROD="7e19226d-e44a-4e60-83d6-cd3f8459b2c6"  # Signature Strawberry Cake

# 1. Standard PICKUP order
ORDER_BODY='{"items":[{"productId":"'$STD_PROD'","quantity":2}],"fulfillmentType":"PICKUP","paymentMethod":"CASH","scheduledFor":"'$TOMORROW'"}'
RESP=$(curl -s -X POST "$API/orders" -H "Authorization: Bearer $CUSTOMER_TOKEN" \
  -H "Content-Type: application/json" -d "$ORDER_BODY")
ORDER_ID=$(echo "$RESP" | grep -oE '"id":"[a-f0-9-]+"' | head -1 | sed 's/"id":"//;s/"$//')
ORDER_CODE=$(echo "$RESP" | grep -oE '"code":"BAN-[^"]+"' | head -1 | sed 's/"code":"//;s/"$//')
[ -n "$ORDER_ID" ] && pass "Place PICKUP order: $ORDER_CODE" || fail "Place PICKUP order"

# 2. Order detail (as customer)
expect_get "Customer reads own order"        "$API/orders/$ORDER_ID" "$CUSTOMER_TOKEN"

# 3. My orders list
expect_get_contains "Order appears in customer list" \
  "$API/orders" "$CUSTOMER_TOKEN" "$ORDER_CODE"

# 4. Merchant sees the order
expect_get_contains "Merchant sees order in queue" \
  "$API/merchant/orders" "$MERCHANT_TOKEN" "$ORDER_CODE"

# 5. PICKUP order with VAT invoice (CASH only valid for PICKUP per
#    backend rule CASH_PICKUP_ONLY — keeps test self-contained without
#    requiring a payment-provider sandbox).
VAT_BODY='{
  "items":[{"productId":"'$BDAY_PROD'","quantity":1}],
  "fulfillmentType":"PICKUP",
  "paymentMethod":"CASH",
  "scheduledFor":"'$TOMORROW'",
  "requestVatInvoice":true,
  "invoiceCompanyName":"Selftest Co.",
  "invoiceTaxId":"0123456789",
  "invoiceAddress":"123 Test Street, P. Bến Nghé",
  "invoiceEmail":"selftest@example.com"
}'
VAT_ORDER=$(curl -s -X POST "$API/orders" -H "Authorization: Bearer $CUSTOMER_TOKEN" \
  -H "Content-Type: application/json" -d "$VAT_BODY")
echo "$VAT_ORDER" | grep -q '"code":"BAN-' \
  && pass "Place PICKUP order with VAT invoice" \
  || fail "VAT order failed: $(echo "$VAT_ORDER" | head -c 200)"
echo "$VAT_ORDER" | grep -q '"requestVatInvoice":true' \
  && pass "VAT invoice request persisted" || fail "VAT invoice request not persisted"
echo "$VAT_ORDER" | grep -q '"invoiceTaxId":"0123456789"' \
  && pass "VAT taxId persisted" || fail "VAT taxId missing"

# 5b. DELIVERY same-ward / other-ward fee check via quote endpoint —
#     full order placement requires a non-CASH payment provider so we
#     verify the fee math via the public quote endpoint instead.
SAMEW=$(curl -s -X POST "$API/geo/delivery-quote" -H "Content-Type: application/json" \
  -d '{"wardCode":"sai-gon","productIds":["'$BDAY_PROD'"]}' \
  | grep -oE '"totalVnd":[0-9]+' | head -1 | sed 's/"totalVnd"://')
[ "$SAMEW" = "30000" ] && pass "Birthday same-ward quote = 30.000₫" \
                       || fail "Birthday same-ward quote = $SAMEW (want 30000)"
OTHERW=$(curl -s -X POST "$API/geo/delivery-quote" -H "Content-Type: application/json" \
  -d '{"wardCode":"binh-thanh","productIds":["'$BDAY_PROD'"]}' \
  | grep -oE '"totalVnd":[0-9]+' | head -1 | sed 's/"totalVnd"://')
[ "$OTHERW" = "70000" ] && pass "Birthday other-ward quote = 70.000₫" \
                        || fail "Birthday other-ward quote = $OTHERW (want 70000)"

# 6. VAT validation — try to submit with toggle on but missing fields
BAD_VAT='{
  "items":[{"productId":"'$STD_PROD'","quantity":1}],
  "fulfillmentType":"PICKUP","paymentMethod":"CASH","scheduledFor":"'$TOMORROW'",
  "requestVatInvoice":true
}'
BAD_RESP=$(curl -s -X POST "$API/orders" -H "Authorization: Bearer $CUSTOMER_TOKEN" \
  -H "Content-Type: application/json" -d "$BAD_VAT")
echo "$BAD_RESP" | grep -q 'INVOICE_FIELDS_REQUIRED' \
  && pass "VAT validation rejects missing company fields" \
  || fail "VAT validation should reject missing fields"

# ─────────────────────────────────────────────────────────────────────────
section "Merchant flow"
expect_get "Merchant menu list"              "$API/products/merchant/list" "$MERCHANT_TOKEN"
expect_get "Merchant collections"            "$API/merchant/collections" "$MERCHANT_TOKEN"
expect_get "Merchant customers (CRM)"        "$API/merchant/customers" "$MERCHANT_TOKEN"
expect_get "Merchant banners"                "$API/banners?merchantView=true" "$MERCHANT_TOKEN"

# Soft-delete (archive) a product that has past orders → expect archived=true
ARCH_RESP=$(curl -s -X DELETE "$API/products/$STD_PROD" -H "Authorization: Bearer $MERCHANT_TOKEN")
echo "$ARCH_RESP" | grep -q '"archived":true' \
  && pass "Delete product-with-orders returns archived=true" \
  || fail "Delete archived response wrong: $ARCH_RESP"

# Restore
RST_RESP=$(curl -s -X POST "$API/products/$STD_PROD/restore" -H "Authorization: Bearer $MERCHANT_TOKEN")
echo "$RST_RESP" | grep -q '"isAvailable":true' \
  && pass "Restore archived product" \
  || fail "Restore product failed"

# ─────────────────────────────────────────────────────────────────────────
section "Admin flow"
expect_get "Admin cross-store orders"        "$API/merchant/orders" "$ADMIN_TOKEN"
expect_get "Admin delivery config"           "$API/geo/delivery-config" "$ADMIN_TOKEN"
expect_get "Admin promo popup config"        "$API/promo-popup" "$ADMIN_TOKEN"
expect_get "Admin customers"                 "$API/merchant/customers" "$ADMIN_TOKEN"

# ─────────────────────────────────────────────────────────────────────────
section "Kitchen flow"
expect_get "Kitchen order queue"             "$API/kitchen/orders" "$KITCHEN_TOKEN"

# ─────────────────────────────────────────────────────────────────────────
section "Reports (Excel export)"
RANGE_FROM=$(date -d "30 days ago" +%Y-%m-%d 2>/dev/null || date -v -30d +%Y-%m-%d)
RANGE_TO=$(date +%Y-%m-%d)
expect_get "Reports summary"                 "$API/merchant/reports/summary?from=$RANGE_FROM&to=$RANGE_TO" "$MERCHANT_TOKEN"
expect_get_contains "Summary has totals.revenue" \
  "$API/merchant/reports/summary?from=$RANGE_FROM&to=$RANGE_TO" "$MERCHANT_TOKEN" '"revenue":'
expect_get "Reports products"                "$API/merchant/reports/products?from=$RANGE_FROM&to=$RANGE_TO&limit=5" "$MERCHANT_TOKEN"
# XLSX export — fetch bytes, verify size + content-type
XLSX_RESP=$(curl -s -o /tmp/selftest-report.xlsx -w "%{http_code}|%{size_download}|%{content_type}" \
  -H "Authorization: Bearer $MERCHANT_TOKEN" \
  "$API/merchant/reports/export.xlsx?from=$RANGE_FROM&to=$RANGE_TO")
XLSX_CODE=$(echo "$XLSX_RESP" | cut -d'|' -f1)
XLSX_SIZE=$(echo "$XLSX_RESP" | cut -d'|' -f2)
XLSX_MIME=$(echo "$XLSX_RESP" | cut -d'|' -f3)
if [ "$XLSX_CODE" = "200" ] && [ "$XLSX_SIZE" -gt 4000 ] && echo "$XLSX_MIME" | grep -q "spreadsheetml"; then
  pass "XLSX export ($XLSX_SIZE bytes, $XLSX_MIME)"
else
  fail "XLSX export bad (code=$XLSX_CODE size=$XLSX_SIZE mime=$XLSX_MIME)"
fi

# ─────────────────────────────────────────────────────────────────────────
section "Recommendations (P1 #11)"
REC_RESP=$(curl -s "$API/products/$BDAY_PROD/recommendations?limit=5")
REC_COUNT=$(echo "$REC_RESP" | grep -oE '"id":"[a-f0-9-]+"' | wc -l)
if [ "$REC_COUNT" -ge 3 ]; then
  pass "Recommendations returned $REC_COUNT items (≥3)"
else
  fail "Recommendations returned only $REC_COUNT items"
fi

# ─────────────────────────────────────────────────────────────────────────
section "Stock indicator + inventory (P1 #12, #13)"
# Find a LIMITED variant from seed (Mango Passion (Summer) has limited stock — slug 'mango-passion-summer')
LIM_PROD_ID=$(curl -s "$API/products?perPage=50" \
  | grep -oE '"id":"[a-f0-9-]+","storeId":"[^"]+","categoryId":"[^"]+","name":"Mango Passion[^"]*"' \
  | head -1 | grep -oE '"id":"[a-f0-9-]+"' | head -1 | sed 's/"id":"//;s/"$//')
if [ -z "$LIM_PROD_ID" ]; then
  # Fallback — any product with LIMITED stockMode
  LIM_PROD_ID=$(curl -s "$API/products?perPage=50" \
    | grep -oE '"id":"[a-f0-9-]+","storeId":"[^"]+","categoryId":"[^"]+","name":"[^"]+","slug":"[^"]+","description":"[^"]+","basePrice":"[^"]+","images":[^]]+\],"tags":[^]]*\],"preparationMinutes":[0-9]+,"isAvailable":true,"isSeasonal":[^,]+,"seasonStart":[^,]+,"seasonEnd":[^,]+,"leadTimeHours":[^,]+,"availableDaysOfWeek":\[[^]]*\],"dailyMaxQuantity":[^,]+,"createdAt":[^,]+,"updatedAt":[^,]+,"variants":\[\{"id":"[a-f0-9-]+","productId":"[a-f0-9-]+","size":"[^"]+","flavor":"[^"]+","priceDelta":"[^"]+","stockMode":"LIMITED"' \
    | head -1 | grep -oE '"id":"[a-f0-9-]+"' | head -1 | sed 's/"id":"//;s/"$//')
fi

if [ -n "$LIM_PROD_ID" ]; then
  pass "Found LIMITED product: $LIM_PROD_ID"
  LIM_VARIANT=$(curl -s "$API/products/$LIM_PROD_ID" | grep -oE '"variants":\[\{[^}]*"stockMode":"LIMITED"[^}]*"stockQty":[0-9]+' | head -1)
  echo "    variant info: $LIM_VARIANT" >&2

  # Try to order 9999 of the LIMITED variant → expect OUT_OF_STOCK
  VID=$(echo "$LIM_VARIANT" | grep -oE '"id":"[a-f0-9-]+"' | head -1 | sed 's/"id":"//;s/"$//')
  OVERSELL=$(curl -s -X POST "$API/orders" \
    -H "Authorization: Bearer $CUSTOMER_TOKEN" -H "Content-Type: application/json" \
    -d "{\"items\":[{\"productId\":\"$LIM_PROD_ID\",\"variantId\":\"$VID\",\"quantity\":9999}],\"fulfillmentType\":\"PICKUP\",\"paymentMethod\":\"CASH\",\"scheduledFor\":\"$TOMORROW\"}")
  if echo "$OVERSELL" | grep -q 'OUT_OF_STOCK'; then
    pass "Oversell rejected with OUT_OF_STOCK"
  else
    fail "Oversell should have been rejected: $(echo "$OVERSELL" | head -c 200)"
  fi
else
  echo "    (no LIMITED variant in catalog — skip oversell test)" >&2
fi

# ─────────────────────────────────────────────────────────────────────────
section "Merchant create customer (UX fix)"
RAND=$((RANDOM * RANDOM % 1000000))
CREATE_RESP=$(curl -s -X POST "$API/merchant/customers" \
  -H "Authorization: Bearer $MERCHANT_TOKEN" -H "Content-Type: application/json" \
  -d "{\"fullName\":\"Selftest Customer $RAND\",\"phone\":\"09${RAND}\",\"notes\":\"selftest\"}")
echo "$CREATE_RESP" | grep -q '"role":"CUSTOMER"' \
  && pass "POST /merchant/customers creates customer" \
  || fail "Create customer failed: $(echo "$CREATE_RESP" | head -c 200)"
# Duplicate → 409
DUP_RESP=$(curl -s -X POST "$API/merchant/customers" \
  -H "Authorization: Bearer $MERCHANT_TOKEN" -H "Content-Type: application/json" \
  -d "{\"fullName\":\"Selftest Customer $RAND\",\"phone\":\"09${RAND}\"}")
echo "$DUP_RESP" | grep -q 'CUSTOMER_EXISTS' \
  && pass "Duplicate phone rejected with CUSTOMER_EXISTS" \
  || fail "Dup should have been rejected"

# ─────────────────────────────────────────────────────────────────────────
section "Product delete UX (P0 follow-up)"
# Hard delete (no orders) — find a product with no order items
HARD_PROD=$(curl -s "$API/products?perPage=50" \
  | grep -oE '"id":"[a-f0-9-]+","storeId":"[^"]+","categoryId":"[^"]+","name":"Basque Burnt Ube \(Whole\)"' \
  | head -1 | grep -oE '"id":"[a-f0-9-]+"' | head -1 | sed 's/"id":"//;s/"$//')
if [ -n "$HARD_PROD" ]; then
  DELETE_OUT=$(curl -s -X DELETE "$API/products/$HARD_PROD" -H "Authorization: Bearer $MERCHANT_TOKEN")
  # Should be either deleted=true OR archived=true (depending on whether it has orders)
  if echo "$DELETE_OUT" | grep -qE '"(deleted|archived)":true'; then
    pass "Product delete returns outcome envelope: $(echo "$DELETE_OUT" | grep -oE '"(deleted|archived)":(true|false)' | tr '\n' ' ')"
  else
    fail "Delete envelope unexpected: $DELETE_OUT"
  fi
fi

# ─────────────────────────────────────────────────────────────────────────
section "Display config toggle (chain-wide)"
DC_DEFAULT=$(curl -s "$API/display-config" | grep -oE '"showStockToCustomers":(true|false)' | head -1)
[ "$DC_DEFAULT" = '"showStockToCustomers":false' ] \
  && pass "Public GET default off" \
  || fail "Default should be false, got: $DC_DEFAULT"

# Toggle on as merchant_owner
TOGGLE_ON=$(curl -s -X PATCH "$API/display-config" \
  -H "Authorization: Bearer $MERCHANT_TOKEN" -H "Content-Type: application/json" \
  -d '{"showStockToCustomers":true}' \
  | grep -oE '"showStockToCustomers":(true|false)' | head -1)
[ "$TOGGLE_ON" = '"showStockToCustomers":true' ] \
  && pass "Merchant PATCH on" \
  || fail "Toggle on failed: $TOGGLE_ON"

# Reset to off
curl -s -X PATCH "$API/display-config" \
  -H "Authorization: Bearer $MERCHANT_TOKEN" -H "Content-Type: application/json" \
  -d '{"showStockToCustomers":false}' -o /dev/null
DC_RESET=$(curl -s "$API/display-config" | grep -oE '"showStockToCustomers":(true|false)' | head -1)
[ "$DC_RESET" = '"showStockToCustomers":false' ] \
  && pass "Reset to off" \
  || fail "Reset failed"

# Unauthenticated PATCH should 401
UNAUTH=$(curl -s -X PATCH "$API/display-config" -H "Content-Type: application/json" -d '{}' -o /dev/null -w "%{http_code}")
[ "$UNAUTH" = "401" ] && pass "Unauthenticated PATCH rejected (401)" || fail "Unauthenticated PATCH = $UNAUTH"

# ─────────────────────────────────────────────────────────────────────────
section "Newsletter (P1 #16)"
NL_EMAIL="selftest+$(date +%s)@example.com"
SUB_RESP=$(curl -s -X POST "$API/newsletter/subscribe" -H "Content-Type: application/json" \
  -d "{\"email\":\"$NL_EMAIL\",\"fullName\":\"Selftest\",\"source\":\"selftest\"}")
echo "$SUB_RESP" | grep -q '"pending":true' \
  && pass "Subscribe new email returns pending=true" \
  || fail "Subscribe response: $SUB_RESP"

# Idempotent re-subscribe (still pending)
SUB2=$(curl -s -X POST "$API/newsletter/subscribe" -H "Content-Type: application/json" \
  -d "{\"email\":\"$NL_EMAIL\"}")
echo "$SUB2" | grep -q '"pending":true' \
  && pass "Re-subscribe still pending (idempotent)" \
  || fail "Re-subscribe response: $SUB2"

# Merchant list — search by timestamp portion (the `+` in the full email
# would be URL-decoded as a space, breaking the query).
NL_QUERY=$(echo "$NL_EMAIL" | sed 's/.*+//;s/@.*//')
MLIST=$(curl -s -H "Authorization: Bearer $MERCHANT_TOKEN" "$API/merchant/newsletter?q=$NL_QUERY")
echo "$MLIST" | grep -q "$NL_EMAIL" \
  && pass "Merchant list returns new subscriber" \
  || fail "Merchant list missing: $MLIST"
echo "$MLIST" | grep -q '"pending":[0-9]\+' \
  && pass "Merchant list has stats" \
  || fail "No stats in: $MLIST"

# CSV export — verify byte size + content-type
CSV_INFO=$(curl -s -o /tmp/selftest-newsletter.csv -w "%{http_code}|%{size_download}|%{content_type}" \
  -H "Authorization: Bearer $MERCHANT_TOKEN" "$API/merchant/newsletter/export.csv")
CSV_CODE=$(echo "$CSV_INFO" | cut -d'|' -f1)
CSV_MIME=$(echo "$CSV_INFO" | cut -d'|' -f3)
if [ "$CSV_CODE" = "200" ] && echo "$CSV_MIME" | grep -q "text/csv"; then
  pass "CSV export ($CSV_MIME)"
else
  fail "CSV export bad: code=$CSV_CODE mime=$CSV_MIME"
fi

# Confirm via token (fetch the token from psql)
NL_TOKEN=$(docker exec banan-postgres psql -U banan -d banan -t -c \
  "SELECT \"unsubscribeToken\" FROM \"NewsletterSubscriber\" WHERE email = '$NL_EMAIL';" \
  | tr -d ' \n')
if [ -n "$NL_TOKEN" ]; then
  CONFIRM=$(curl -s "$API/newsletter/confirm?token=$NL_TOKEN")
  echo "$CONFIRM" | grep -q "$NL_EMAIL" \
    && pass "Confirm via token" \
    || fail "Confirm failed: $CONFIRM"
  # After confirm, subscribe should report alreadyConfirmed
  AFTER=$(curl -s -X POST "$API/newsletter/subscribe" -H "Content-Type: application/json" \
    -d "{\"email\":\"$NL_EMAIL\"}")
  echo "$AFTER" | grep -q '"alreadyConfirmed":true' \
    && pass "Subscribe after confirm reports alreadyConfirmed" \
    || fail "Post-confirm response: $AFTER"
  # Unsubscribe
  UNSUB=$(curl -s "$API/newsletter/unsubscribe?token=$NL_TOKEN")
  echo "$UNSUB" | grep -q "$NL_EMAIL" \
    && pass "Unsubscribe via token" \
    || fail "Unsubscribe failed: $UNSUB"
fi

# Invalid email → 400
BAD=$(curl -s -X POST "$API/newsletter/subscribe" -H "Content-Type: application/json" \
  -d '{"email":"not-an-email"}')
echo "$BAD" | grep -q '"error"' \
  && pass "Invalid email rejected" \
  || fail "Should have rejected: $BAD"

# Block @banan.local emails (guest synth)
SYNTH=$(curl -s -X POST "$API/newsletter/subscribe" -H "Content-Type: application/json" \
  -d '{"email":"0903@guest.banan.local"}')
echo "$SYNTH" | grep -q 'INVALID_EMAIL' \
  && pass "Guest synth email rejected" \
  || fail "Synth response: $SYNTH"

# ─────────────────────────────────────────────────────────────────────────
section "Cake personalization wizard (P1 #8)"
echo "$( curl -s "$API/products/$BDAY_PROD" | grep -oE '"isBirthdayCake":(true|false)' | head -1)" \
  | grep -q '"isBirthdayCake":true' \
  && pass "Birthday cake → isBirthdayCake=true" \
  || fail "Bday flag wrong"

curl -s "$API/products/$STD_PROD" | grep -oE '"isBirthdayCake":(true|false)' | head -1 \
  | grep -q '"isBirthdayCake":false' \
  && pass "Standard product → isBirthdayCake=false" \
  || fail "Non-bday flag wrong"

# Place order with personalization payload
PERSON_BODY='{
  "items":[{
    "productId":"'$BDAY_PROD'","quantity":1,
    "personalization":{
      "textOnCake":"Chuc mung sinh nhat An",
      "candleCount":7,
      "note":"Ribbon vang, khong sprinkles"
    }
  }],
  "fulfillmentType":"PICKUP","paymentMethod":"CASH","scheduledFor":"'$TOMORROW'"
}'
PERSON_ORDER=$(curl -s -X POST "$API/orders" -H "Authorization: Bearer $CUSTOMER_TOKEN" \
  -H "Content-Type: application/json" -d "$PERSON_BODY")
echo "$PERSON_ORDER" | grep -q '"code":"BAN-' \
  && pass "Order with personalization created" \
  || fail "Order failed: $(echo "$PERSON_ORDER" | head -c 200)"

# Verify the OrderItem actually persisted personalization
echo "$PERSON_ORDER" | grep -q '"candleCount":7' \
  && pass "candleCount persisted in OrderItem" \
  || fail "candleCount missing"
echo "$PERSON_ORDER" | grep -q '"textOnCake"' \
  && pass "textOnCake persisted" \
  || fail "textOnCake missing"

# Empty personalization on non-bday product — backend accepts but stores null
EMPTY_BODY='{
  "items":[{
    "productId":"'$STD_PROD'","quantity":1
  }],
  "fulfillmentType":"PICKUP","paymentMethod":"CASH","scheduledFor":"'$TOMORROW'"
}'
EMPTY_ORDER=$(curl -s -X POST "$API/orders" -H "Authorization: Bearer $CUSTOMER_TOKEN" \
  -H "Content-Type: application/json" -d "$EMPTY_BODY")
if echo "$EMPTY_ORDER" | grep -q '"code":"BAN-'; then
  # personalization should be null (not present, or null) — accept either
  PERS_RAW=$(echo "$EMPTY_ORDER" | grep -oE '"personalization":[^,}]*' | head -1)
  if [ -z "$PERS_RAW" ] || echo "$PERS_RAW" | grep -q 'null'; then
    pass "Order without personalization persists null"
  else
    fail "Expected null personalization, got: $PERS_RAW"
  fi
fi

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
