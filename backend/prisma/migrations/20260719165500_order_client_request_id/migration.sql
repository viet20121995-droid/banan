-- Client-generated dedup key for staff-entered orders (counter / internal
-- transfer): a retried POST with the same (creator, key) returns the first
-- order instead of creating a duplicate.
ALTER TABLE "Order" ADD COLUMN "clientRequestId" TEXT;

-- Unique per creator; Postgres treats NULLs as distinct, so WEB orders
-- (both columns null) are unaffected.
CREATE UNIQUE INDEX "Order_createdById_clientRequestId_key"
  ON "Order"("createdById", "clientRequestId");
