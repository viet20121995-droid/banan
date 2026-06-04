-- Each store decides how far in advance of a scheduled pickup/delivery time
-- the kitchen / counter should start preparing. Default 2 hours.
ALTER TABLE "Store"
  ADD COLUMN "preparationLeadMinutes" INTEGER NOT NULL DEFAULT 120;

-- Tracks when the scheduler first surfaced a scheduled order as "due soon",
-- preventing duplicate emissions on subsequent cron ticks.
ALTER TABLE "Order"
  ADD COLUMN "dueSoonNotifiedAt" TIMESTAMP(3);
