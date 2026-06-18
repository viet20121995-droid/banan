-- Combo/bundle support in orders: record the combo savings as a discount line.
-- A cart line that is a Bundle is expanded into its constituent products at
-- regular prices; the difference vs the bundle's flat priceVnd is stored here.
-- Additive column with a default → safe on existing rows.
ALTER TABLE "Order"
  ADD COLUMN "bundleDiscount" DECIMAL(12, 2) NOT NULL DEFAULT 0;
