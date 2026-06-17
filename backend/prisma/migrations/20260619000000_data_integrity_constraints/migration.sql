-- Data-integrity FKs + campaign-redemption ledger (backend review, Batch D).
--
-- DEFENSIVE: every constraint is preceded by a cleanup of any pre-existing
-- orphan reference, so `prisma migrate deploy` cannot fail on production data
-- (a failed migration would block the container from booting).

-- 1. LoyaltyEvent.orderId -> Order (SET NULL). The points ledger is
--    money-adjacent; give its order reference a real FK. First null out any
--    orderId that doesn't point at a live order.
UPDATE "LoyaltyEvent" e
  SET "orderId" = NULL
  WHERE e."orderId" IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM "Order" o WHERE o.id = e."orderId");

ALTER TABLE "LoyaltyEvent"
  ADD CONSTRAINT "LoyaltyEvent_orderId_fkey"
  FOREIGN KEY ("orderId") REFERENCES "Order"("id")
  ON DELETE SET NULL ON UPDATE CASCADE;

CREATE INDEX "LoyaltyEvent_orderId_idx" ON "LoyaltyEvent"("orderId");

-- 2. ProductionBatch FKs. Remove batches whose product is gone (operational
--    data, safe to drop); null out a missing variant.
DELETE FROM "ProductionBatch" b
  WHERE NOT EXISTS (SELECT 1 FROM "Product" p WHERE p.id = b."productId");

UPDATE "ProductionBatch" b
  SET "variantId" = NULL
  WHERE b."variantId" IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM "ProductVariant" v WHERE v.id = b."variantId");

ALTER TABLE "ProductionBatch"
  ADD CONSTRAINT "ProductionBatch_productId_fkey"
  FOREIGN KEY ("productId") REFERENCES "Product"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "ProductionBatch"
  ADD CONSTRAINT "ProductionBatch_variantId_fkey"
  FOREIGN KEY ("variantId") REFERENCES "ProductVariant"("id")
  ON DELETE SET NULL ON UPDATE CASCADE;

CREATE INDEX "ProductionBatch_productId_idx" ON "ProductionBatch"("productId");

-- 3. CampaignRedemption ledger — backs per-user / global campaign limits
--    (previously unenforceable, so usageLimit / perUserLimit did nothing).
CREATE TABLE "CampaignRedemption" (
  "id"         TEXT NOT NULL,
  "campaignId" TEXT NOT NULL,
  "userId"     TEXT NOT NULL,
  "orderId"    TEXT NOT NULL,
  "createdAt"  TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "CampaignRedemption_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "CampaignRedemption_campaignId_userId_orderId_key"
  ON "CampaignRedemption"("campaignId", "userId", "orderId");

CREATE INDEX "CampaignRedemption_campaignId_userId_idx"
  ON "CampaignRedemption"("campaignId", "userId");

ALTER TABLE "CampaignRedemption"
  ADD CONSTRAINT "CampaignRedemption_campaignId_fkey"
  FOREIGN KEY ("campaignId") REFERENCES "Campaign"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;
