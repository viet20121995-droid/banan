-- Set the base tier default to BRONZE (separate migration so the new enum
-- value from 20260606020000 is already committed before it is referenced).
ALTER TABLE "User" ALTER COLUMN "membershipTier" SET DEFAULT 'BRONZE';
