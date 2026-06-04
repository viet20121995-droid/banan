-- Merchant-only CRM fields on User: private staff notes + tags.

ALTER TABLE "User"
  ADD COLUMN "merchantNotes" TEXT,
  ADD COLUMN "merchantTags" TEXT[] DEFAULT ARRAY[]::TEXT[];
