-- Singleton delivery-pricing config edited by admins. Carries two tiers
-- (standard products vs. birthday cake collection) × two distance bands
-- (within `thresholdKm` vs. beyond).
--
-- Default values reflect the current policy:
--   - Standard under 3km : 0 ₫
--   - Standard over 3km  : 15.000 ₫
--   - Birthday cake bands: admin-configurable (seed with reasonable cake fees)
CREATE TABLE "DeliveryConfig" (
  "id"                            TEXT NOT NULL,
  "standardFeeUnder3kmVnd"        INTEGER NOT NULL DEFAULT 0,
  "standardFeeOver3kmVnd"         INTEGER NOT NULL DEFAULT 15000,
  "birthdayCakeFeeUnder3kmVnd"    INTEGER NOT NULL DEFAULT 30000,
  "birthdayCakeFeeOver3kmVnd"     INTEGER NOT NULL DEFAULT 45000,
  "birthdayCakeCollectionSlug"    TEXT NOT NULL DEFAULT 'birthday-cakes',
  "thresholdKm"                   DOUBLE PRECISION NOT NULL DEFAULT 3,
  "updatedAt"                     TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "DeliveryConfig_pkey" PRIMARY KEY ("id")
);

-- Seed the singleton row immediately so every read finds it.
INSERT INTO "DeliveryConfig" ("id", "updatedAt") VALUES ('default', CURRENT_TIMESTAMP);
