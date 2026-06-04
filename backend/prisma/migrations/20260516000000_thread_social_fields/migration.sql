-- Instagram-style thread upgrades: carousel images, hashtags, product link,
-- CTA button, scheduled publishing, and an impression counter.

ALTER TABLE "Thread"
  ADD COLUMN "images" TEXT[] DEFAULT ARRAY[]::TEXT[],
  ADD COLUMN "hashtags" TEXT[] DEFAULT ARRAY[]::TEXT[],
  ADD COLUMN "productId" TEXT,
  ADD COLUMN "ctaLabel" TEXT,
  ADD COLUMN "ctaUrl" TEXT,
  ADD COLUMN "scheduledPublishAt" TIMESTAMP(3),
  ADD COLUMN "viewCount" INTEGER NOT NULL DEFAULT 0;

ALTER TABLE "Thread"
  ADD CONSTRAINT "Thread_productId_fkey"
  FOREIGN KEY ("productId") REFERENCES "Product"("id")
  ON DELETE SET NULL ON UPDATE CASCADE;

CREATE INDEX "Thread_scheduledPublishAt_idx"
  ON "Thread"("scheduledPublishAt");
