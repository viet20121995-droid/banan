-- Soft-hide a category from the customer storefront (chip + home strip +
-- all its products). Merchant/admin still see it to unhide.
ALTER TABLE "Category" ADD COLUMN "isHidden" BOOLEAN NOT NULL DEFAULT false;
