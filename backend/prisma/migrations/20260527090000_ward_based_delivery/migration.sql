-- Switch delivery pricing from distance bands (≤3km / >3km) to ward
-- equality (same ward as the routed store / different ward). Adds a
-- `wardCode` to Store and renames the four DeliveryConfig fee columns
-- so their names match the new semantics.

ALTER TABLE "Store"
  ADD COLUMN "wardCode" TEXT;

-- Pre-populate ward codes for the seeded HCMC branches so the new rule
-- has data to compare against on first boot. Slugs match `hcm-wards.ts`.
UPDATE "Store" SET "wardCode" = 'sai-gon'    WHERE "slug" = 'banan-le-thanh-ton';
UPDATE "Store" SET "wardCode" = 'hoa-hung'   WHERE "slug" = 'banan-su-van-hanh';
UPDATE "Store" SET "wardCode" = 'an-khanh'   WHERE "slug" = 'banan-ngo-quang-huy';
UPDATE "Store" SET "wardCode" = 'cau-kieu'   WHERE "slug" = 'banan-truong-sa';

-- Rename DeliveryConfig columns + adjust defaults to the new pricing
-- (standard: 0 same ward / 30k other; birthday: 30k same / 70k other).
ALTER TABLE "DeliveryConfig"
  RENAME COLUMN "standardFeeUnder3kmVnd"     TO "standardFeeSameWardVnd";
ALTER TABLE "DeliveryConfig"
  RENAME COLUMN "standardFeeOver3kmVnd"      TO "standardFeeOtherWardVnd";
ALTER TABLE "DeliveryConfig"
  RENAME COLUMN "birthdayCakeFeeUnder3kmVnd" TO "birthdayCakeFeeSameWardVnd";
ALTER TABLE "DeliveryConfig"
  RENAME COLUMN "birthdayCakeFeeOver3kmVnd"  TO "birthdayCakeFeeOtherWardVnd";

-- Apply the new defaults + adjust existing row to match.
ALTER TABLE "DeliveryConfig" ALTER COLUMN "standardFeeSameWardVnd"     SET DEFAULT 0;
ALTER TABLE "DeliveryConfig" ALTER COLUMN "standardFeeOtherWardVnd"    SET DEFAULT 30000;
ALTER TABLE "DeliveryConfig" ALTER COLUMN "birthdayCakeFeeSameWardVnd" SET DEFAULT 30000;
ALTER TABLE "DeliveryConfig" ALTER COLUMN "birthdayCakeFeeOtherWardVnd" SET DEFAULT 70000;

UPDATE "DeliveryConfig" SET
  "standardFeeSameWardVnd" = 0,
  "standardFeeOtherWardVnd" = 30000,
  "birthdayCakeFeeSameWardVnd" = 30000,
  "birthdayCakeFeeOtherWardVnd" = 70000
WHERE "id" = 'default';
