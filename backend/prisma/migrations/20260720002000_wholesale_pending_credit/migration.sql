-- A submitted wholesale order reserves credit, but its payment term only
-- starts when an admin confirms it and sends it to the kitchen.
ALTER TYPE "WholesaleReceivableStatus" ADD VALUE 'PENDING' BEFORE 'OPEN';

ALTER TABLE "WholesaleAccount"
  ADD COLUMN "deliveryAddress" TEXT;

ALTER TABLE "WholesaleReceivable"
  ALTER COLUMN "dueDate" DROP NOT NULL;
