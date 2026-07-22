-- Suppliers + purchase orders for the MES (Phase 2: Purchase + Inventory).
CREATE TYPE "MfgPoState" AS ENUM ('DRAFT', 'CONFIRMED', 'PARTIAL', 'RECEIVED', 'CANCELLED');

CREATE TABLE "MfgSupplier" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "phone" TEXT,
    "email" TEXT,
    "address" TEXT,
    "note" TEXT,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "MfgSupplier_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "MfgPurchaseOrder" (
    "id" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "supplierId" TEXT NOT NULL,
    "state" "MfgPoState" NOT NULL DEFAULT 'DRAFT',
    "expectedDate" TIMESTAMP(3),
    "note" TEXT,
    "createdById" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "MfgPurchaseOrder_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "MfgPurchaseOrderLine" (
    "id" TEXT NOT NULL,
    "poId" TEXT NOT NULL,
    "productId" TEXT NOT NULL,
    "qty" DECIMAL(14,3) NOT NULL,
    "qtyReceived" DECIMAL(14,3) NOT NULL DEFAULT 0,
    "uomId" TEXT NOT NULL,
    "unitPrice" DECIMAL(14,2) NOT NULL,

    CONSTRAINT "MfgPurchaseOrderLine_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "MfgPurchaseOrder_code_key" ON "MfgPurchaseOrder"("code");
CREATE INDEX "MfgPurchaseOrder_state_idx" ON "MfgPurchaseOrder"("state");
CREATE INDEX "MfgPurchaseOrderLine_poId_idx" ON "MfgPurchaseOrderLine"("poId");
CREATE INDEX "MfgPurchaseOrderLine_productId_idx" ON "MfgPurchaseOrderLine"("productId");

ALTER TABLE "MfgPurchaseOrder" ADD CONSTRAINT "MfgPurchaseOrder_supplierId_fkey" FOREIGN KEY ("supplierId") REFERENCES "MfgSupplier"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "MfgPurchaseOrderLine" ADD CONSTRAINT "MfgPurchaseOrderLine_poId_fkey" FOREIGN KEY ("poId") REFERENCES "MfgPurchaseOrder"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "MfgPurchaseOrderLine" ADD CONSTRAINT "MfgPurchaseOrderLine_productId_fkey" FOREIGN KEY ("productId") REFERENCES "MfgProduct"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "MfgPurchaseOrderLine" ADD CONSTRAINT "MfgPurchaseOrderLine_uomId_fkey" FOREIGN KEY ("uomId") REFERENCES "MfgUom"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
