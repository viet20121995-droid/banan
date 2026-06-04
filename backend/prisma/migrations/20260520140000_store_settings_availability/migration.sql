-- Store operating settings: pause toggle, lead time, minimum order, blackout
-- dates. Plus per-product availability rules so merchants can express
-- "bánh sinh nhật cần đặt trước 48 giờ" / "trà chiều chỉ bán T2-T6".

ALTER TABLE "Store"
  ADD COLUMN "isPaused" BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN "pauseReason" TEXT,
  ADD COLUMN "minOrderVnd" INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN "defaultLeadHours" INTEGER NOT NULL DEFAULT 0;

-- Per-product availability overrides. `availableDaysOfWeek` follows
-- JS Date.getDay() — 0=Sun, 1=Mon, ..., 6=Sat. Empty array means "every day".
ALTER TABLE "Product"
  ADD COLUMN "leadTimeHours" INTEGER,
  ADD COLUMN "availableDaysOfWeek" INTEGER[] NOT NULL DEFAULT ARRAY[]::INTEGER[],
  ADD COLUMN "dailyMaxQuantity" INTEGER;

-- Blackout dates: storeId + date is unique so a merchant can't queue a date
-- twice. `reason` is shown to the customer when an order is blocked.
CREATE TABLE "StoreBlackoutDate" (
  "id"        TEXT NOT NULL,
  "storeId"   TEXT NOT NULL,
  "date"      DATE NOT NULL,
  "reason"    TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "StoreBlackoutDate_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "StoreBlackoutDate_storeId_date_key"
  ON "StoreBlackoutDate" ("storeId", "date");

CREATE INDEX "StoreBlackoutDate_storeId_idx"
  ON "StoreBlackoutDate" ("storeId");

ALTER TABLE "StoreBlackoutDate"
  ADD CONSTRAINT "StoreBlackoutDate_storeId_fkey"
  FOREIGN KEY ("storeId") REFERENCES "Store"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;
