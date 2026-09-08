-- Per-variant image (customer detail swaps the cover when a size/flavour is
-- picked) + admin-set link for the seasonal hero "explore" button.
ALTER TABLE "ProductVariant" ADD COLUMN "imageUrl" TEXT;
ALTER TABLE "DisplayConfig" ADD COLUMN "heroCtaUrl" TEXT;
