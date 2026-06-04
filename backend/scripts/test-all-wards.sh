#!/bin/bash
# Run delivery-quote for every HCMC ward — both Standard and Birthday cake.
# Verifies the ward-equality rule end-to-end across the whole catalog.

set -e

API=http://localhost:3000/api/v1
BDAY_PROD=$(curl -s "$API/products?perPage=20" \
  | grep -oE '"id":"[^"]*","storeId":"[^"]*","categoryId":"[^"]*","name":"Signature' \
  | head -1 | grep -oE '"id":"[^"]*"' | head -1 | sed 's/.*:"//;s/"//')

if [ -z "$BDAY_PROD" ]; then
  echo "ERR: no birthday product found" >&2
  exit 1
fi

WARDS_JSON=$(curl -s "$API/geo/hcm-wards")
WARD_CODES=$(echo "$WARDS_JSON" | grep -oE '"code":"[^"]*"' | sed 's/"code":"//;s/"//')

printf "%-22s | %-8s | %-22s | %-10s | %-10s\n" \
  "WARD" "DIST(km)" "ROUTED STORE" "STANDARD" "BIRTHDAY"
printf "%s\n" "$(printf -- '-%.0s' {1..90})"

extract_field() {
  local json="$1" key="$2"
  echo "$json" | grep -oE "\"$key\":[^,}]*" | head -1 | sed "s/\"$key\"://;s/^\"//;s/\"$//"
}

while read -r ward; do
  [ -z "$ward" ] && continue

  std=$(curl -s -X POST "$API/geo/delivery-quote" \
    -H "Content-Type: application/json" \
    -d "{\"wardCode\":\"$ward\",\"productIds\":[]}")
  bday=$(curl -s -X POST "$API/geo/delivery-quote" \
    -H "Content-Type: application/json" \
    -d "{\"wardCode\":\"$ward\",\"productIds\":[\"$BDAY_PROD\"]}")

  std_fee=$(extract_field "$std" totalVnd)
  bday_fee=$(extract_field "$bday" totalVnd)
  dist=$(extract_field "$std" distanceKm)
  store=$(echo "$std" | grep -oE '"name":"Banan[^"]*"' | head -1 \
    | sed 's/"name":"//;s/"$//;s/Banan – //')

  printf "%-22s | %-8s | %-22s | %-10s | %-10s\n" \
    "$ward" "$dist" "$store" "$std_fee" "$bday_fee"
done <<< "$WARD_CODES"
