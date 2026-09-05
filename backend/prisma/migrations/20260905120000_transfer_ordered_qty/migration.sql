-- Keep the branch's original request when the kitchen adjusts a transfer line.
ALTER TABLE "OrderItem" ADD COLUMN "orderedQty" INTEGER;
ALTER TABLE "InternalTransferMfgItem" ADD COLUMN "orderedQty" DECIMAL(14,3);
