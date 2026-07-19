-- Reconcile pre-ledger reservations (increment 9).
-- The advisory model tracked reservedQty as an unowned running total. Under the
-- hard-reservation model, stock is only released via MfgReservation rows, so any
-- reservedQty with no backing ledger row can never be freed. Zero those orphans
-- on both the quant and the (open-MO) component; the order can simply re-reserve.
-- On a fresh deploy this matches zero rows; it only matters where a pre-migration
-- reserve left a hold behind.

UPDATE "MfgStockQuant" q
SET "reservedQty" = 0
WHERE q."reservedQty" <> 0
  AND NOT EXISTS (SELECT 1 FROM "MfgReservation" r WHERE r."quantId" = q."id");

UPDATE "MfgOrderComponent" c
SET "reservedQty" = 0
WHERE c."reservedQty" <> 0
  AND NOT EXISTS (
    SELECT 1 FROM "MfgReservation" r
    WHERE r."moId" = c."moId" AND r."productId" = c."productId"
  );
