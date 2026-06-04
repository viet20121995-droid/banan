-- Home-page hero banners, managed by merchants (store-scoped) or admin
-- (chain-wide, storeId NULL).

CREATE TABLE "Banner" (
  "id"        TEXT NOT NULL,
  "storeId"   TEXT,
  "imageUrl"  TEXT NOT NULL,
  "title"     TEXT,
  "ctaUrl"    TEXT,
  "sortOrder" INTEGER NOT NULL DEFAULT 0,
  "isActive"  BOOLEAN NOT NULL DEFAULT true,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "Banner_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "Banner_storeId_isActive_idx" ON "Banner"("storeId", "isActive");

ALTER TABLE "Banner"
  ADD CONSTRAINT "Banner_storeId_fkey"
  FOREIGN KEY ("storeId") REFERENCES "Store"("id")
  ON DELETE SET NULL ON UPDATE CASCADE;
