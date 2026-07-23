-- AlterTable
ALTER TABLE "WholesaleContract" ADD COLUMN     "nextDayCutoffMinutes" INTEGER,
ADD COLUMN     "noDeliveryDays" INTEGER[] DEFAULT ARRAY[]::INTEGER[],
ADD COLUMN     "shipFeeVnd" INTEGER NOT NULL DEFAULT 0;

-- AlterTable
ALTER TABLE "WholesaleContractLine" ADD COLUMN     "deliveryDays" INTEGER[] DEFAULT ARRAY[]::INTEGER[],
ADD COLUMN     "leadTimeDays" INTEGER,
ADD COLUMN     "multipleQty" INTEGER NOT NULL DEFAULT 1;
