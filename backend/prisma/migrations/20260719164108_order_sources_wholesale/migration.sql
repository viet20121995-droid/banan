-- CreateEnum
CREATE TYPE "OrderSource" AS ENUM ('WEB', 'STAFF_COUNTER', 'WHOLESALE', 'INTERNAL_TRANSFER');

-- CreateEnum
CREATE TYPE "SettlementMode" AS ENUM ('ONLINE', 'COUNTER_PAID', 'COUNTER_UNPAID', 'ON_ACCOUNT', 'INTERNAL_LEDGER');

-- CreateEnum
CREATE TYPE "WholesaleReceivableStatus" AS ENUM ('OPEN', 'PARTIAL', 'PAID', 'OVERDUE', 'CANCELLED');

-- AlterTable
ALTER TABLE "Order" ADD COLUMN     "createdById" TEXT,
ADD COLUMN     "destinationStoreId" TEXT,
ADD COLUMN     "requestingStoreId" TEXT,
ADD COLUMN     "settlementMode" "SettlementMode" NOT NULL DEFAULT 'ONLINE',
ADD COLUMN     "source" "OrderSource" NOT NULL DEFAULT 'WEB',
ADD COLUMN     "wholesaleAccountId" TEXT,
ADD COLUMN     "wholesaleContractId" TEXT;

-- CreateTable
CREATE TABLE "WholesaleAccount" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "companyName" TEXT NOT NULL,
    "contactName" TEXT,
    "contactPhone" TEXT,
    "taxId" TEXT,
    "billingEmail" TEXT,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "creditLimitVnd" INTEGER NOT NULL DEFAULT 0,
    "paymentTermDays" INTEGER NOT NULL DEFAULT 30,
    "blockedReason" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "WholesaleAccount_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "WholesaleContract" (
    "id" TEXT NOT NULL,
    "wholesaleAccountId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "startsAt" TIMESTAMP(3) NOT NULL,
    "endsAt" TIMESTAMP(3),
    "active" BOOLEAN NOT NULL DEFAULT true,
    "minOrderVnd" INTEGER,
    "defaultDiscountPct" DECIMAL(5,2),
    "paymentTermDays" INTEGER,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "WholesaleContract_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "WholesaleContractLine" (
    "id" TEXT NOT NULL,
    "contractId" TEXT NOT NULL,
    "productId" TEXT NOT NULL,
    "variantId" TEXT,
    "fixedPriceVnd" INTEGER,
    "discountPct" DECIMAL(5,2),
    "minQty" INTEGER NOT NULL DEFAULT 1,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "leadTimeHours" INTEGER,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "WholesaleContractLine_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "WholesaleReceivable" (
    "id" TEXT NOT NULL,
    "wholesaleAccountId" TEXT NOT NULL,
    "orderId" TEXT NOT NULL,
    "amountVnd" DECIMAL(12,2) NOT NULL,
    "dueDate" TIMESTAMP(3) NOT NULL,
    "status" "WholesaleReceivableStatus" NOT NULL DEFAULT 'OPEN',
    "paidAt" TIMESTAMP(3),
    "confirmedByAdminId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "WholesaleReceivable_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "WholesaleAccount_userId_key" ON "WholesaleAccount"("userId");

-- CreateIndex
CREATE INDEX "WholesaleContract_wholesaleAccountId_active_idx" ON "WholesaleContract"("wholesaleAccountId", "active");

-- CreateIndex
CREATE INDEX "WholesaleContractLine_contractId_active_idx" ON "WholesaleContractLine"("contractId", "active");

-- CreateIndex
CREATE UNIQUE INDEX "WholesaleReceivable_orderId_key" ON "WholesaleReceivable"("orderId");

-- CreateIndex
CREATE INDEX "WholesaleReceivable_wholesaleAccountId_status_idx" ON "WholesaleReceivable"("wholesaleAccountId", "status");

-- CreateIndex
CREATE INDEX "Order_source_createdAt_idx" ON "Order"("source", "createdAt");

-- AddForeignKey
ALTER TABLE "Order" ADD CONSTRAINT "Order_createdById_fkey" FOREIGN KEY ("createdById") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Order" ADD CONSTRAINT "Order_wholesaleAccountId_fkey" FOREIGN KEY ("wholesaleAccountId") REFERENCES "WholesaleAccount"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Order" ADD CONSTRAINT "Order_wholesaleContractId_fkey" FOREIGN KEY ("wholesaleContractId") REFERENCES "WholesaleContract"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Order" ADD CONSTRAINT "Order_requestingStoreId_fkey" FOREIGN KEY ("requestingStoreId") REFERENCES "Store"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Order" ADD CONSTRAINT "Order_destinationStoreId_fkey" FOREIGN KEY ("destinationStoreId") REFERENCES "Store"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "WholesaleAccount" ADD CONSTRAINT "WholesaleAccount_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "WholesaleContract" ADD CONSTRAINT "WholesaleContract_wholesaleAccountId_fkey" FOREIGN KEY ("wholesaleAccountId") REFERENCES "WholesaleAccount"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "WholesaleContractLine" ADD CONSTRAINT "WholesaleContractLine_contractId_fkey" FOREIGN KEY ("contractId") REFERENCES "WholesaleContract"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "WholesaleContractLine" ADD CONSTRAINT "WholesaleContractLine_productId_fkey" FOREIGN KEY ("productId") REFERENCES "Product"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "WholesaleContractLine" ADD CONSTRAINT "WholesaleContractLine_variantId_fkey" FOREIGN KEY ("variantId") REFERENCES "ProductVariant"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "WholesaleReceivable" ADD CONSTRAINT "WholesaleReceivable_wholesaleAccountId_fkey" FOREIGN KEY ("wholesaleAccountId") REFERENCES "WholesaleAccount"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "WholesaleReceivable" ADD CONSTRAINT "WholesaleReceivable_orderId_fkey" FOREIGN KEY ("orderId") REFERENCES "Order"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
