-- Review round: (1) dedup key on receivable payments — a retried confirm
-- returns the first ledger entry instead of collecting twice; (2) structured
-- goods-receipt for internal transfers (per-line received vs ordered).
ALTER TABLE "WholesalePayment" ADD COLUMN "clientRequestId" TEXT;

CREATE UNIQUE INDEX "WholesalePayment_receivableId_clientRequestId_key"
  ON "WholesalePayment"("receivableId", "clientRequestId");

CREATE TABLE "InternalTransferReceipt" (
  "id" TEXT NOT NULL,
  "orderId" TEXT NOT NULL,
  "receivedById" TEXT NOT NULL,
  "note" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "InternalTransferReceipt_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "InternalTransferReceipt_orderId_key"
  ON "InternalTransferReceipt"("orderId");

ALTER TABLE "InternalTransferReceipt"
  ADD CONSTRAINT "InternalTransferReceipt_orderId_fkey"
  FOREIGN KEY ("orderId") REFERENCES "Order"("id")
  ON DELETE RESTRICT ON UPDATE CASCADE;

CREATE TABLE "InternalTransferReceiptLine" (
  "id" TEXT NOT NULL,
  "receiptId" TEXT NOT NULL,
  "orderItemId" TEXT NOT NULL,
  "orderedQty" INTEGER NOT NULL,
  "receivedQty" INTEGER NOT NULL,
  CONSTRAINT "InternalTransferReceiptLine_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "InternalTransferReceiptLine_receiptId_idx"
  ON "InternalTransferReceiptLine"("receiptId");

ALTER TABLE "InternalTransferReceiptLine"
  ADD CONSTRAINT "InternalTransferReceiptLine_receiptId_fkey"
  FOREIGN KEY ("receiptId") REFERENCES "InternalTransferReceipt"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;
