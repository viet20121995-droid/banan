-- Per-product list of branches that do not serve it.
ALTER TABLE "Product" ADD COLUMN "excludedStoreIds" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[];
