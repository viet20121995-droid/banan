-- Unified SKU on sellable variants (maps 1-1 to MfgProduct.code).
ALTER TABLE "ProductVariant" ADD COLUMN "sku" TEXT;

CREATE UNIQUE INDEX "ProductVariant_sku_key" ON "ProductVariant"("sku");
