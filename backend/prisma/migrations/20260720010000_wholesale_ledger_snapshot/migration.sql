-- Wholesale hardening round:
-- 1) Order.wholesaleInfo — order-time snapshot of company/delivery/PO info so
--    editing the account never rewrites what old orders display.
-- 2) Receivable partial payments: paidAmountVnd running total + a payment
--    ledger (who collected how much, when, how, with bank reference).
ALTER TABLE "Order" ADD COLUMN "wholesaleInfo" JSONB;

ALTER TABLE "WholesaleReceivable"
  ADD COLUMN "paidAmountVnd" DECIMAL(12,2) NOT NULL DEFAULT 0;

CREATE TABLE "WholesalePayment" (
  "id" TEXT NOT NULL,
  "receivableId" TEXT NOT NULL,
  "amountVnd" DECIMAL(12,2) NOT NULL,
  "method" TEXT NOT NULL DEFAULT 'BANK_TRANSFER',
  "reference" TEXT,
  "note" TEXT,
  "confirmedByAdminId" TEXT NOT NULL,
  "paidAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "WholesalePayment_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "WholesalePayment_receivableId_idx"
  ON "WholesalePayment"("receivableId");

ALTER TABLE "WholesalePayment"
  ADD CONSTRAINT "WholesalePayment_receivableId_fkey"
  FOREIGN KEY ("receivableId") REFERENCES "WholesaleReceivable"("id")
  ON DELETE RESTRICT ON UPDATE CASCADE;

-- Receivables already PAID keep their history consistent: treat them as fully
-- collected in one (unrecorded) payment.
UPDATE "WholesaleReceivable" SET "paidAmountVnd" = "amountVnd"
  WHERE "status" = 'PAID';
