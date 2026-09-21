-- Display-only "was" price shown struck through next to the selling price.
ALTER TABLE "Product" ADD COLUMN "compareAtPrice" DECIMAL(12,2);
