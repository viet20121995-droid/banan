-- CreateEnum
CREATE TYPE "CampaignType" AS ENUM ('PRODUCT_DISCOUNT', 'CATEGORY_DISCOUNT', 'FLASH_SALE', 'HAPPY_HOUR', 'BUY_X_GET_Y', 'FIRST_ORDER', 'BIRTHDAY', 'REACTIVATION', 'MEMBERSHIP_BENEFIT');

-- AlterTable
ALTER TABLE "Order" ADD COLUMN     "campaignDiscount" DECIMAL(12,2) NOT NULL DEFAULT 0,
ADD COLUMN     "campaignInfo" JSONB;

-- CreateTable
CREATE TABLE "Campaign" (
    "id" TEXT NOT NULL,
    "type" "CampaignType" NOT NULL,
    "name" TEXT NOT NULL,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "priority" INTEGER NOT NULL DEFAULT 0,
    "stackable" BOOLEAN NOT NULL DEFAULT true,
    "startsAt" TIMESTAMP(3),
    "endsAt" TIMESTAMP(3),
    "config" JSONB NOT NULL,
    "storeId" TEXT,
    "usageLimit" INTEGER,
    "usedCount" INTEGER NOT NULL DEFAULT 0,
    "perUserLimit" INTEGER,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Campaign_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "Campaign_type_idx" ON "Campaign"("type");

-- CreateIndex
CREATE INDEX "Campaign_isActive_idx" ON "Campaign"("isActive");
