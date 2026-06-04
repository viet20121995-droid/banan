-- Simplify KitchenStatus enum: drop the intermediate bake-stage columns and
-- introduce PENDING_ACK at the start. Any active orders in the dropped
-- statuses get coerced to PREPARING so they don't block the migration.

-- 1. Coerce existing rows away from soon-to-be-dropped values.
UPDATE "Order"
SET "kitchenStatus" = 'PREPARING'
WHERE "kitchenStatus" IN ('BAKING', 'COOLING', 'DECORATING', 'PACKED');

-- 2. Replace the enum. Postgres requires create-new → swap → drop-old.
CREATE TYPE "KitchenStatus_new" AS ENUM ('PENDING_ACK', 'PREPARING', 'READY_DISPATCH');
ALTER TABLE "Order"
  ALTER COLUMN "kitchenStatus" TYPE "KitchenStatus_new"
  USING ("kitchenStatus"::text::"KitchenStatus_new");
DROP TYPE "KitchenStatus";
ALTER TYPE "KitchenStatus_new" RENAME TO "KitchenStatus";
