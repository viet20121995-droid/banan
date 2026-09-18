-- One-off re-base of Micho balances after the earn rate changed from
-- 1 Micho / 50 000₫ to 1 Micho / 10 000₫ (18/09/2026). Idempotent: guarded
-- by the ADJUSTMENT reason so a re-run adds nothing.
\echo === before
SELECT count(*) FILTER (WHERE "pointsBalance" >= 500) AS eligible_500, count(*) FILTER (WHERE "pointsBalance" > 0) AS with_points, sum("pointsBalance") AS total_micho FROM "User" WHERE role='CUSTOMER';
BEGIN;
CREATE TEMP TABLE rebase AS
WITH web AS (
  SELECT e."userId", sum(floor(o.subtotal / 10000) - e.delta)::int AS extra
  FROM "LoyaltyEvent" e JOIN "Order" o ON o.id = e."orderId"
  WHERE e.type = 'EARN' GROUP BY 1
), counter AS (
  SELECT id AS "userId", (floor("cukcukSpendVnd" / 10000.0) - floor("cukcukSpendVnd" / 50000.0))::int AS extra
  FROM "User" WHERE "cukcukSpendVnd" > 0
)
SELECT u.id AS "userId", coalesce(w.extra, 0) + coalesce(c.extra, 0) AS extra
FROM "User" u LEFT JOIN web w ON w."userId" = u.id LEFT JOIN counter c ON c."userId" = u.id
WHERE coalesce(w.extra, 0) + coalesce(c.extra, 0) > 0
  AND NOT EXISTS (SELECT 1 FROM "LoyaltyEvent" x WHERE x."userId" = u.id AND x.reason = 'Quy đổi lại Micho: 1 Micho / 10.000₫ (18/09/2026)');
\echo === users to re-base
SELECT count(*), sum(extra) FROM rebase;
UPDATE "User" u SET "pointsBalance" = u."pointsBalance" + r.extra FROM rebase r WHERE u.id = r."userId";
INSERT INTO "LoyaltyEvent" (id, "userId", type, delta, "balanceAfter", reason, "createdAt")
SELECT gen_random_uuid(), r."userId", 'ADJUSTMENT', r.extra, u."pointsBalance", 'Quy đổi lại Micho: 1 Micho / 10.000₫ (18/09/2026)', now()
FROM rebase r JOIN "User" u ON u.id = r."userId";
UPDATE "User" SET "membershipTier" = (CASE WHEN "pointsBalance" >= 25000 THEN 'PLATINUM' WHEN "pointsBalance" >= 10000 THEN 'GOLD' WHEN "pointsBalance" >= 2500 THEN 'SILVER' ELSE 'BRONZE' END)::"MembershipTier" WHERE role='CUSTOMER';
COMMIT;
\echo === after
SELECT count(*) FILTER (WHERE "pointsBalance" >= 500) AS eligible_500, count(*) FILTER (WHERE "pointsBalance" > 0) AS with_points, sum("pointsBalance") AS total_micho FROM "User" WHERE role='CUSTOMER';
SELECT "membershipTier", count(*) FROM "User" WHERE role='CUSTOMER' GROUP BY 1;
