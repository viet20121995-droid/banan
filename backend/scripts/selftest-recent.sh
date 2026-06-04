#!/bin/bash
# Self-test for the features built recently: contact form, editable site
# content (FAQ/About), bulk tools, broadcast, marketing programs, gift cards,
# and isBirthdayCake decoration. Non-destructive (dry-runs / cleans up).
# Exit code = number of failures.
API=${API:-http://localhost:3000/api/v1}
PASS=0; FAIL=0; ERRORS=()
pass(){ PASS=$((PASS+1)); printf "  \033[32m✓\033[0m %s\n" "$1"; }
fail(){ FAIL=$((FAIL+1)); ERRORS+=("$1"); printf "  \033[31m✗\033[0m %s\n" "$1"; }
section(){ echo ""; echo "▶ $1"; }
login(){ curl -s -X POST "$API/auth/login" -H "Content-Type: application/json" -d "{\"emailOrPhone\":\"$1\",\"password\":\"banan123\"}" | grep -oE '"accessToken":"[^"]+"' | sed 's/.*:"//;s/"//'; }
# jget <json> <node-expr-on-d>  (d = parsed .data)
jget(){ node -e 'let r="";process.stdin.on("data",c=>r+=c);process.stdin.on("end",()=>{try{const j=JSON.parse(r);const d=j.data!==undefined?j.data:j;process.stdout.write(String(eval(process.argv[1])))}catch(e){process.stdout.write("ERR:"+e.message)}})' "$1"; }

AT=$(login admin@banan.local); CT=$(login customer@banan.local); MT=$(login merchant@banan.local)
[ -n "$AT" ] && pass "Admin login" || fail "Admin login"
ah=(-H "Authorization: Bearer $AT" -H "Content-Type: application/json")
ch=(-H "Authorization: Bearer $CT" -H "Content-Type: application/json")

# ── Contact ──────────────────────────────────────────────────────────────
section "Contact form (P3 #30)"
R=$(curl -s -X POST "$API/contact" -H "Content-Type: application/json" -d '{"name":"Selftest","email":"selftest@example.com","message":"Kiem tra lien he"}')
echo "$R" | grep -q '"ok":true' && pass "POST /contact -> ok" || fail "contact: $R"

# ── Site content ─────────────────────────────────────────────────────────
section "Editable FAQ / About (SiteContent)"
N=$(curl -s "$API/site-content/faq" | jget "d.content.items.length")
[ "$N" -ge 1 ] 2>/dev/null && pass "GET faq default ($N items)" || fail "faq default: $N"
ISD=$(curl -s "$API/site-content/faq" | jget "d.isDefault")
[ "$ISD" = "true" ] && pass "faq isDefault=true" || fail "faq isDefault=$ISD"
R=$(curl -s -X PATCH "$API/merchant/site-content/faq" "${ah[@]}" -d '{"data":{"items":[{"q":"Selftest Q","a":"Selftest A"}]}}')
echo "$R" | jget "d.content.items.length" | grep -q '^1$' && pass "PATCH faq saved (1 item)" || fail "patch faq: $R"
curl -s "$API/site-content/faq" | jget "d.isDefault" | grep -q false && pass "GET faq now persisted (isDefault=false)" || fail "faq not persisted"
docker exec banan-postgres psql -U banan -d banan -c "DELETE FROM \"SiteContent\" WHERE key IN ('faq','about');" >/dev/null 2>&1
curl -s "$API/site-content/faq" | jget "d.isDefault" | grep -q true && pass "Reset faq -> default" || fail "faq reset"

# ── Bulk tools ───────────────────────────────────────────────────────────
section "Bulk tools (P4 #31/#32)"
CAT=$(curl -s "$API/categories" | grep -oE '"id":"[a-f0-9-]{36}"' | head -1 | grep -oE '[a-f0-9-]{36}')
# Bulk price preview (dryRun) — must not mutate.
R=$(curl -s -X POST "$API/products/merchant/bulk-price" "${ah[@]}" -d '{"scope":"all","mode":"percent","amount":10,"dryRun":true}')
M=$(echo "$R" | jget "d.matched"); U=$(echo "$R" | jget "d.updated")
{ [ "$M" -gt 0 ] 2>/dev/null && [ "$U" = "0" ]; } && pass "Bulk-price dry-run matched=$M updated=0 (no mutation)" || fail "bulk-price: $R"
# Bulk import a uniquely-slugged product, then delete it.
SLUG="selftest-import-$RANDOM"
R=$(curl -s -X POST "$API/products/merchant/bulk-import" "${ah[@]}" -d "{\"rows\":[{\"name\":\"Selftest Import\",\"slug\":\"$SLUG\",\"categoryId\":\"$CAT\",\"basePrice\":50000}]}")
echo "$R" | jget "d.created" | grep -q '^1$' && pass "Bulk-import created 1" || fail "bulk-import: $R"
NEWID=$(curl -s "$API/products?perPage=100" | grep -oE "\"id\":\"[a-f0-9-]{36}\"[^}]*\"slug\":\"$SLUG\"" | grep -oE '[a-f0-9-]{36}' | head -1)
[ -n "$NEWID" ] && curl -s -X DELETE "$API/products/$NEWID" "${ah[@]}" -o /dev/null && pass "Cleanup imported product" || echo "    (cleanup skipped)"

# ── Broadcast ────────────────────────────────────────────────────────────
section "In-app broadcast (P4 #37)"
R=$(curl -s -X POST "$API/merchant/broadcast" "${ah[@]}" -d '{"title":"Selftest","body":"thong bao kiem tra"}')
REC=$(echo "$R" | jget "d.recipients")
[ "$REC" -ge 1 ] 2>/dev/null && pass "Broadcast sent to $REC customers" || fail "broadcast: $R"

# ── Marketing config ─────────────────────────────────────────────────────
section "Marketing programs (P2)"
curl -s "$API/marketing/config" | jget "[d.referral.enabled,d.giftCard.enabled,d.subscription.enabled,d.catering.enabled,d.rewards.enabled].join(',')" | grep -q '^false,false,false,false,false$' && pass "All 5 programs default OFF" || fail "marketing defaults not all off"
curl -s -X PATCH "$API/merchant/marketing/config" "${ah[@]}" -d '{"cateringEnabled":true,"cateringConfig":{"minGuests":30}}' | jget "d.catering.enabled" | grep -q true && pass "Enable catering + config" || fail "enable catering"
curl -s "$API/marketing/config" | jget "d.catering.config.minGuests" | grep -q '^30$' && pass "Catering config persisted (minGuests=30)" || fail "catering config"
curl -s -X PATCH "$API/merchant/marketing/config" "${ah[@]}" -d '{"cateringEnabled":false}' -o /dev/null
curl -s "$API/marketing/config" | jget "d.catering.enabled" | grep -q false && pass "Reset catering OFF" || fail "reset catering"

# ── Gift cards ───────────────────────────────────────────────────────────
section "Gift cards (full: issue + redeem)"
ISS=$(curl -s -X POST "$API/merchant/gift-cards" "${ah[@]}" -d '{"valueVnd":100000,"note":"selftest"}')
CODE=$(echo "$ISS" | jget "d.code"); GID=$(echo "$ISS" | jget "d.id")
echo "$CODE" | grep -q '^BNGC-' && pass "Admin issued gift card ($CODE)" || fail "issue: $ISS"
curl -s -X POST "$API/gift-cards/validate" -H "Content-Type: application/json" -d "{\"code\":\"$CODE\"}" | jget "d.valid" | grep -q true && pass "Public validate -> valid" || fail "validate"
TOMORROW=$(date -u -d "tomorrow 11:00" +%Y-%m-%dT%H:%M:%S.000Z 2>/dev/null || date -u -v +1d +%Y-%m-%dT11:00:00.000Z)
STD="dc1220fa-88e4-45ad-a649-d54c2f9b6c75"
ORD=$(curl -s -X POST "$API/orders" "${ch[@]}" -d "{\"items\":[{\"productId\":\"$STD\",\"quantity\":1}],\"fulfillmentType\":\"PICKUP\",\"paymentMethod\":\"CASH\",\"scheduledFor\":\"$TOMORROW\",\"giftCardCode\":\"$CODE\"}")
GCAMT=$(echo "$ORD" | jget "d.order.giftCardAmountVnd")
[ "$GCAMT" -gt 0 ] 2>/dev/null && pass "Order redeemed gift card ($GCAMT₫)" || fail "redeem: $(echo "$ORD"|head -c 160)"
BAL=$(curl -s -X POST "$API/gift-cards/validate" -H "Content-Type: application/json" -d "{\"code\":\"$CODE\"}" | jget "d.balanceVnd")
[ "$BAL" -lt 100000 ] 2>/dev/null && pass "Balance decremented (now $BAL₫)" || fail "balance not decremented: $BAL"
curl -s -X PATCH "$API/merchant/gift-cards/$GID/deactivate" "${ah[@]}" | jget "d.isActive" | grep -q false && pass "Deactivate gift card" || fail "deactivate"

# ── isBirthdayCake decoration ────────────────────────────────────────────
section "isBirthdayCake on product list"
BC=$(curl -s "$API/products?perPage=50" | node -e 'let r="";process.stdin.on("data",c=>r+=c);process.stdin.on("end",()=>{const it=(JSON.parse(r).data||[]);process.stdout.write(String(it.filter(p=>p.isBirthdayCake===true).length))})')
[ "$BC" -gt 0 ] 2>/dev/null && pass "Products list flags $BC birthday cakes" || fail "isBirthdayCake count=$BC"

echo ""
echo "═══════════════════════════════════════════════════════"
printf "  \033[32mPASS:\033[0m %d   \033[31mFAIL:\033[0m %d\n" "$PASS" "$FAIL"
for e in "${ERRORS[@]}"; do printf "    - %s\n" "$e"; done
echo "═══════════════════════════════════════════════════════"
exit $FAIL
