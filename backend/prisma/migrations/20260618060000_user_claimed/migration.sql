-- Add `claimed` to mark accounts whose owner proved control (self-registered
-- or password-reset). Guest/merchant stubs stay false.
ALTER TABLE "User" ADD COLUMN "claimed" BOOLEAN NOT NULL DEFAULT false;

-- Backfill: treat every account that is NOT a synthetic stub as claimed, so
-- existing real users are protected from guest-checkout binding immediately.
-- Stub emails: 'guest+<hex>@banan.local' (guest checkout) and
-- '<digits>@guest.banan.local' (merchant-created phone customer).
UPDATE "User"
SET "claimed" = true
WHERE "email" NOT LIKE 'guest+%@banan.local'
  AND "email" NOT LIKE '%@guest.banan.local';
