-- AlterTable: gift-order fields ("tặng quà khi đặt hàng")
ALTER TABLE "Order" ADD COLUMN     "giftMessage" TEXT,
ADD COLUMN     "giftRecipientName" TEXT,
ADD COLUMN     "giftRecipientPhone" TEXT,
ADD COLUMN     "giftWrap" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "hidePrice" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "isGift" BOOLEAN NOT NULL DEFAULT false;
