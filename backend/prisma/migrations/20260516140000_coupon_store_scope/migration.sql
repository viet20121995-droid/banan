-- Store-scoped promo codes: a coupon may belong to a store (merchant-issued)
-- or be chain-wide (storeId NULL, admin-issued). Adds a label + createdAt
-- for the merchant coupon manager.

ALTER TABLE "Coupon"
  ADD COLUMN "storeId" TEXT,
  ADD COLUMN "label" TEXT,
  ADD COLUMN "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE "Coupon"
  ADD CONSTRAINT "Coupon_storeId_fkey"
  FOREIGN KEY ("storeId") REFERENCES "Store"("id")
  ON DELETE SET NULL ON UPDATE CASCADE;

CREATE INDEX "Coupon_storeId_idx" ON "Coupon"("storeId");
