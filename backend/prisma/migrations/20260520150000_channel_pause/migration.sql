-- Channel-specific pause toggles. Master `isPaused` still blocks both
-- channels (kept for the existing "emergency shutdown" UX); the two new
-- flags let the merchant pause just pickup or just delivery.
--
-- Order check: an order is rejected when
--   (isPaused) OR (PICKUP && isPickupPaused) OR (DELIVERY && isDeliveryPaused).
ALTER TABLE "Store"
  ADD COLUMN "isPickupPaused"   BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN "isDeliveryPaused" BOOLEAN NOT NULL DEFAULT FALSE;
