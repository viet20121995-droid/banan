-- Read-only scan for combos (Bundles) that are invalid under the post-review
-- rules. SELECT-only — safe to run on production. Run on the server:
--
--   docker exec -i banan-postgres-1 psql -U banan -d banan \
--     < /opt/banan/backend/scripts/scan-invalid-bundles.sql
--
-- Each section lists offending bundles. `is_active = t` rows are the ones that
-- actually matter (inactive combos can't be ordered). Fix them in the merchant
-- admin (edit + save re-validates) or ask to auto-deactivate the active ones.

\echo '=== 1) Combo chứa sản phẩm CHỌN VỊ (flavorPickCount > 0) ==='
SELECT b.id, b.name, b."isActive" AS is_active, p.name AS flavor_product
FROM "Bundle" b
JOIN "BundleItem" bi ON bi."bundleId" = b.id
JOIN "Product" p ON p.id = bi."productId"
WHERE COALESCE(p."flavorPickCount", 0) > 0
ORDER BY b."isActive" DESC, b.name;

\echo ''
\echo '=== 2) Variant không thuộc đúng product ==='
SELECT b.id, b.name, b."isActive" AS is_active, p.name AS product, bi."variantId"
FROM "Bundle" b
JOIN "BundleItem" bi ON bi."bundleId" = b.id
JOIN "Product" p ON p.id = bi."productId"
WHERE bi."variantId" IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM "ProductVariant" v
    WHERE v.id = bi."variantId" AND v."productId" = bi."productId"
  )
ORDER BY b."isActive" DESC, b.name;

\echo ''
\echo '=== 3) Giá combo CAO HƠN tổng giá lẻ (combo không còn ưu đãi) ==='
WITH item_price AS (
  SELECT
    bi."bundleId",
    bi.quantity,
    p."basePrice" + COALESCE(
      (SELECT v."priceDelta" FROM "ProductVariant" v
        WHERE v.id = bi."variantId" AND v."productId" = p.id),
      (SELECT v2."priceDelta" FROM "ProductVariant" v2
        WHERE v2."productId" = p.id
        ORDER BY v2.size ASC, v2.flavor ASC LIMIT 1),
      0
    ) AS unit
  FROM "BundleItem" bi
  JOIN "Product" p ON p.id = bi."productId"
)
SELECT
  b.id, b.name, b."isActive" AS is_active,
  b."priceVnd" AS combo_price,
  SUM(ip.unit * ip.quantity)::bigint AS regular_sum
FROM "Bundle" b
JOIN item_price ip ON ip."bundleId" = b.id
GROUP BY b.id, b.name, b."isActive", b."priceVnd"
HAVING b."priceVnd" > SUM(ip.unit * ip.quantity)
ORDER BY b."isActive" DESC, b.name;

\echo ''
\echo '=== 4) Combo có các món với NGÀY BÁN xung đột (không có ngày chung) ==='
WITH day_parts AS (
  SELECT bi."bundleId", p."availableDaysOfWeek" AS days
  FROM "BundleItem" bi
  JOIN "Product" p ON p.id = bi."productId"
  WHERE COALESCE(array_length(p."availableDaysOfWeek", 1), 0) > 0
),
common_day AS (
  SELECT bb."bundleId", d
  FROM (SELECT DISTINCT "bundleId" FROM day_parts) bb
  CROSS JOIN generate_series(0, 6) AS d
  WHERE NOT EXISTS (
    SELECT 1 FROM day_parts dp
    WHERE dp."bundleId" = bb."bundleId" AND NOT (d = ANY(dp.days))
  )
)
SELECT b.id, b.name, b."isActive" AS is_active
FROM "Bundle" b
WHERE EXISTS (SELECT 1 FROM day_parts dp WHERE dp."bundleId" = b.id)
  AND NOT EXISTS (SELECT 1 FROM common_day c WHERE c."bundleId" = b.id)
ORDER BY b."isActive" DESC, b.name;
