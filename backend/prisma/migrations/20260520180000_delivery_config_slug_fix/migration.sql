-- Align the default birthday-cake collection slug with the actual seed
-- output. seed-catalog.ts prefixes every group collection with `home-`,
-- so the real slug is `home-birthday-cakes`, not `birthday-cakes`.
ALTER TABLE "DeliveryConfig"
  ALTER COLUMN "birthdayCakeCollectionSlug" SET DEFAULT 'home-birthday-cakes';
