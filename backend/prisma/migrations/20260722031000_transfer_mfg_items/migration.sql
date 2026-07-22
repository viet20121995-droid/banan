-- Internal transfers can carry kitchen-warehouse (MES) goods: milk, fruit,
-- cups, packaging. Issued from MES stock (STOCK -> STORE) on branch receipt.
CREATE TABLE "InternalTransferMfgItem" (
    "id" TEXT NOT NULL,
    "orderId" TEXT NOT NULL,
    "mfgProductId" TEXT NOT NULL,
    "qty" DECIMAL(14,3) NOT NULL,
    "receivedQty" DECIMAL(14,3),

    CONSTRAINT "InternalTransferMfgItem_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "InternalTransferMfgItem_orderId_idx" ON "InternalTransferMfgItem"("orderId");

ALTER TABLE "InternalTransferMfgItem" ADD CONSTRAINT "InternalTransferMfgItem_orderId_fkey" FOREIGN KEY ("orderId") REFERENCES "Order"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "InternalTransferMfgItem" ADD CONSTRAINT "InternalTransferMfgItem_mfgProductId_fkey" FOREIGN KEY ("mfgProductId") REFERENCES "MfgProduct"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- Destination location for goods issued to the counter. Idempotent.
CREATE EXTENSION IF NOT EXISTS pgcrypto;
INSERT INTO "MfgLocation" ("id", "code", "nameVi", "nameEn", "type")
SELECT gen_random_uuid(), 'STORE', 'Quầy cửa hàng', 'Store counter', 'INTERNAL'
WHERE NOT EXISTS (SELECT 1 FROM "MfgLocation" WHERE "code" = 'STORE');
