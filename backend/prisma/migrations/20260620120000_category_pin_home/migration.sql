-- Featured categories on the customer home page (replacing Collection strips).
ALTER TABLE "Category" ADD COLUMN "isPinnedToHome" BOOLEAN NOT NULL DEFAULT false;
