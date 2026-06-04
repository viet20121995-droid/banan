#!/usr/bin/env bash
# End-to-end smoke test of all 4 roles against the running API.
# Usage: bash smoke.sh   (backend must be up on :3000)
set -u
BASE=http://localhost:3000/api/v1
PASS=0; FAIL=0

login() { # email -> echoes access token
  curl -s -m 10 -X POST "$BASE/auth/login" -H 'Content-Type: application/json' \
    -d "{\"emailOrPhone\":\"$1\",\"password\":\"banan123\"}" \
    | grep -o '"accessToken":"[^"]*"' | cut -d'"' -f4
}

check() { # label expected method path [token]
  local label="$1" exp="$2" method="$3" path="$4" tok="${5:-}"
  local args=(-s -m 10 -o /dev/null -w '%{http_code}' -X "$method" "$BASE$path")
  [ -n "$tok" ] && args+=(-H "Authorization: Bearer $tok")
  local code; code=$(curl "${args[@]}")
  if [ "$code" = "$exp" ]; then PASS=$((PASS+1)); echo "  ok   [$code] $label";
  else FAIL=$((FAIL+1)); echo "  FAIL [$code != $exp] $label"; fi
}

echo "== AUTH =="
CT=$(login customer@banan.local);  echo "  customer token: ${CT:+ok}"
MT=$(login merchant@banan.local);  echo "  merchant token: ${MT:+ok}"
KT=$(login kitchen@banan.local);   echo "  kitchen  token: ${KT:+ok}"
AT=$(login admin@banan.local);     echo "  admin    token: ${AT:+ok}"

echo "== CUSTOMER =="
check "GET /products"          200 GET  "/products?perPage=5"        "$CT"
check "GET /banners (public)"  200 GET  "/banners"                   ""
check "GET /orders (mine)"     200 GET  "/orders"                    "$CT"
check "GET /me/loyalty"        200 GET  "/me/loyalty"                "$CT"
check "GET /addresses"         200 GET  "/addresses"                 "$CT"
check "customer blocked /admin/users" 403 GET "/admin/users"         "$CT"

echo "== MERCHANT =="
check "GET /merchant/orders"      200 GET "/merchant/orders"         "$MT"
check "GET /merchant/customers"   200 GET "/merchant/customers"      "$MT"
check "GET /merchant/coupons"     200 GET "/merchant/coupons"        "$MT"
check "GET /merchant/banners"     200 GET "/merchant/banners"        "$MT"
check "merchant blocked /admin/users" 403 GET "/admin/users"         "$MT"

echo "== KITCHEN =="
check "GET /kitchen/orders"       200 GET "/kitchen/orders"          "$KT"

echo "== ADMIN =="
check "GET /admin/users"          200 GET "/admin/users"             "$AT"
check "GET /admin/stores"         200 GET "/admin/stores"            "$AT"
check "GET /admin/kitchens"       200 GET "/admin/kitchens"          "$AT"
check "GET /merchant/coupons"     200 GET "/merchant/coupons"        "$AT"

echo "== UNAUTH =="
check "no token -> /orders"       401 GET "/orders"                  ""
check "health"                    200 GET "/health"                  ""

echo
echo "RESULT: $PASS passed, $FAIL failed"
exit $FAIL
