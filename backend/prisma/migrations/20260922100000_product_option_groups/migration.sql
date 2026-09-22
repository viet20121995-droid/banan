-- Per-product choice groups (sugar / ice / cream …), picked on the product page.
ALTER TABLE "Product" ADD COLUMN "optionGroups" JSONB;
