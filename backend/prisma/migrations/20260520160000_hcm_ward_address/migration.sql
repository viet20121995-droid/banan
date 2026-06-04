-- HCMC 2025 administrative reform: districts (quận/huyện) abolished;
-- wards/communes (phường/xã) now sit directly under the city. Address.wardCode
-- references our hard-coded ward catalog so the backend can resolve a
-- centroid (lat/lng) for distance-based delivery surcharges.
--
-- `district` is kept (nullable) for backward-compatible reads of pre-reform
-- addresses; new addresses leave it null and rely on `wardCode` instead.
ALTER TABLE "Address"
  ADD COLUMN "wardCode" TEXT;

CREATE INDEX "Address_wardCode_idx" ON "Address" ("wardCode");
