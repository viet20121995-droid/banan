-- CreateEnum
CREATE TYPE "MfgProductType" AS ENUM ('RAW', 'SEMI', 'FINISHED', 'PACKAGING');

-- CreateEnum
CREATE TYPE "MfgCostMethod" AS ENUM ('AVCO', 'STANDARD');

-- CreateEnum
CREATE TYPE "MfgTracking" AS ENUM ('NONE', 'LOT');

-- CreateEnum
CREATE TYPE "MfgLocationType" AS ENUM ('INTERNAL', 'SUPPLIER', 'PRODUCTION', 'SCRAP');

-- CreateEnum
CREATE TYPE "MfgMoState" AS ENUM ('DRAFT', 'CONFIRMED', 'PROGRESS', 'DONE', 'CANCEL');

-- CreateEnum
CREATE TYPE "MfgAvailability" AS ENUM ('AVAILABLE', 'NOT_AVAILABLE');

-- CreateEnum
CREATE TYPE "MfgWoState" AS ENUM ('PENDING', 'READY', 'PROGRESS', 'BLOCKED', 'DONE', 'CANCEL');

-- CreateEnum
CREATE TYPE "MfgMoveRef" AS ENUM ('RECEIPT', 'DELIVERY', 'INTERNAL', 'MO', 'SCRAP');

-- CreateTable
CREATE TABLE "MfgUom" (
    "id" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "nameVi" TEXT NOT NULL,
    "nameEn" TEXT NOT NULL,
    "category" TEXT NOT NULL,
    "factor" DECIMAL(14,6) NOT NULL,
    "rounding" DECIMAL(14,6) NOT NULL DEFAULT 0.001,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "MfgUom_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MfgCategory" (
    "id" TEXT NOT NULL,
    "nameVi" TEXT NOT NULL,
    "nameEn" TEXT NOT NULL,
    "costMethod" "MfgCostMethod" NOT NULL DEFAULT 'AVCO',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "MfgCategory_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MfgProduct" (
    "id" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "nameVi" TEXT NOT NULL,
    "nameEn" TEXT NOT NULL,
    "categoryId" TEXT NOT NULL,
    "uomId" TEXT NOT NULL,
    "type" "MfgProductType" NOT NULL,
    "tracking" "MfgTracking" NOT NULL DEFAULT 'NONE',
    "useExpiration" BOOLEAN NOT NULL DEFAULT false,
    "expirationDays" INTEGER NOT NULL DEFAULT 0,
    "standardCost" DECIMAL(14,2) NOT NULL DEFAULT 0,
    "avgCost" DECIMAL(14,2) NOT NULL DEFAULT 0,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "MfgProduct_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MfgWorkCenter" (
    "id" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "nameVi" TEXT NOT NULL,
    "nameEn" TEXT NOT NULL,
    "costPerHour" DECIMAL(14,2) NOT NULL DEFAULT 0,
    "capacity" INTEGER NOT NULL DEFAULT 1,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "MfgWorkCenter_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MfgBom" (
    "id" TEXT NOT NULL,
    "productId" TEXT NOT NULL,
    "outputQty" DECIMAL(14,3) NOT NULL DEFAULT 1,
    "uomId" TEXT NOT NULL,
    "version" INTEGER NOT NULL DEFAULT 1,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "MfgBom_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MfgBomLine" (
    "id" TEXT NOT NULL,
    "bomId" TEXT NOT NULL,
    "componentId" TEXT NOT NULL,
    "qty" DECIMAL(14,3) NOT NULL,
    "uomId" TEXT NOT NULL,
    "ratioPercent" DECIMAL(9,4) NOT NULL DEFAULT 0,

    CONSTRAINT "MfgBomLine_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MfgBomOperation" (
    "id" TEXT NOT NULL,
    "bomId" TEXT NOT NULL,
    "sequence" INTEGER NOT NULL,
    "nameVi" TEXT NOT NULL,
    "nameEn" TEXT NOT NULL,
    "workCenterId" TEXT NOT NULL,
    "durationMinutes" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "MfgBomOperation_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MfgBomByproduct" (
    "id" TEXT NOT NULL,
    "bomId" TEXT NOT NULL,
    "productId" TEXT NOT NULL,
    "qty" DECIMAL(14,3) NOT NULL,

    CONSTRAINT "MfgBomByproduct_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MfgLocation" (
    "id" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "nameVi" TEXT NOT NULL,
    "nameEn" TEXT NOT NULL,
    "type" "MfgLocationType" NOT NULL DEFAULT 'INTERNAL',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "MfgLocation_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MfgLot" (
    "id" TEXT NOT NULL,
    "productId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "mfgDate" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expiryDate" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "MfgLot_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MfgStockQuant" (
    "id" TEXT NOT NULL,
    "productId" TEXT NOT NULL,
    "lotId" TEXT,
    "locationId" TEXT NOT NULL,
    "quantity" DECIMAL(14,3) NOT NULL DEFAULT 0,
    "reservedQty" DECIMAL(14,3) NOT NULL DEFAULT 0,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "MfgStockQuant_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MfgStockMove" (
    "id" TEXT NOT NULL,
    "productId" TEXT NOT NULL,
    "lotId" TEXT,
    "qty" DECIMAL(14,3) NOT NULL,
    "uomId" TEXT NOT NULL,
    "srcLocationId" TEXT NOT NULL,
    "destLocationId" TEXT NOT NULL,
    "refType" "MfgMoveRef" NOT NULL,
    "refId" TEXT,
    "unitCost" DECIMAL(14,2) NOT NULL DEFAULT 0,
    "date" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "MfgStockMove_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MfgOrder" (
    "id" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "productId" TEXT NOT NULL,
    "bomId" TEXT NOT NULL,
    "qtyToProduce" DECIMAL(14,3) NOT NULL,
    "qtyProduced" DECIMAL(14,3) NOT NULL DEFAULT 0,
    "uomId" TEXT NOT NULL,
    "state" "MfgMoState" NOT NULL DEFAULT 'DRAFT',
    "scheduledDate" TIMESTAMP(3),
    "responsibleId" TEXT,
    "lotId" TEXT,
    "totalCost" DECIMAL(14,2) NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "MfgOrder_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MfgOrderComponent" (
    "id" TEXT NOT NULL,
    "moId" TEXT NOT NULL,
    "productId" TEXT NOT NULL,
    "qtyToConsume" DECIMAL(14,3) NOT NULL,
    "qtyConsumed" DECIMAL(14,3) NOT NULL DEFAULT 0,
    "uomId" TEXT NOT NULL,
    "availability" "MfgAvailability" NOT NULL DEFAULT 'NOT_AVAILABLE',
    "reservedQty" DECIMAL(14,3) NOT NULL DEFAULT 0,

    CONSTRAINT "MfgOrderComponent_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MfgWorkOrder" (
    "id" TEXT NOT NULL,
    "moId" TEXT NOT NULL,
    "bomOperationId" TEXT NOT NULL,
    "workCenterId" TEXT NOT NULL,
    "sequence" INTEGER NOT NULL,
    "state" "MfgWoState" NOT NULL DEFAULT 'PENDING',
    "durationExpected" INTEGER NOT NULL DEFAULT 0,
    "durationReal" INTEGER NOT NULL DEFAULT 0,
    "dateStart" TIMESTAMP(3),
    "dateFinished" TIMESTAMP(3),

    CONSTRAINT "MfgWorkOrder_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MfgScrap" (
    "id" TEXT NOT NULL,
    "productId" TEXT NOT NULL,
    "lotId" TEXT,
    "qty" DECIMAL(14,3) NOT NULL,
    "uomId" TEXT NOT NULL,
    "locationId" TEXT NOT NULL,
    "reason" TEXT NOT NULL,
    "moId" TEXT,
    "date" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "MfgScrap_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "MfgUom_code_key" ON "MfgUom"("code");

-- CreateIndex
CREATE UNIQUE INDEX "MfgProduct_code_key" ON "MfgProduct"("code");

-- CreateIndex
CREATE INDEX "MfgProduct_type_active_idx" ON "MfgProduct"("type", "active");

-- CreateIndex
CREATE UNIQUE INDEX "MfgWorkCenter_code_key" ON "MfgWorkCenter"("code");

-- CreateIndex
CREATE INDEX "MfgBom_productId_active_idx" ON "MfgBom"("productId", "active");

-- CreateIndex
CREATE INDEX "MfgBomLine_bomId_idx" ON "MfgBomLine"("bomId");

-- CreateIndex
CREATE UNIQUE INDEX "MfgBomOperation_bomId_sequence_key" ON "MfgBomOperation"("bomId", "sequence");

-- CreateIndex
CREATE UNIQUE INDEX "MfgLocation_code_key" ON "MfgLocation"("code");

-- CreateIndex
CREATE INDEX "MfgLot_expiryDate_idx" ON "MfgLot"("expiryDate");

-- CreateIndex
CREATE UNIQUE INDEX "MfgLot_productId_name_key" ON "MfgLot"("productId", "name");

-- CreateIndex
CREATE INDEX "MfgStockQuant_productId_lotId_locationId_idx" ON "MfgStockQuant"("productId", "lotId", "locationId");

-- CreateIndex
CREATE UNIQUE INDEX "MfgStockQuant_productId_lotId_locationId_key" ON "MfgStockQuant"("productId", "lotId", "locationId");

-- CreateIndex
CREATE INDEX "MfgStockMove_productId_date_idx" ON "MfgStockMove"("productId", "date");

-- CreateIndex
CREATE INDEX "MfgStockMove_refType_refId_idx" ON "MfgStockMove"("refType", "refId");

-- CreateIndex
CREATE INDEX "MfgStockMove_lotId_idx" ON "MfgStockMove"("lotId");

-- CreateIndex
CREATE UNIQUE INDEX "MfgOrder_code_key" ON "MfgOrder"("code");

-- CreateIndex
CREATE INDEX "MfgOrder_state_idx" ON "MfgOrder"("state");

-- CreateIndex
CREATE INDEX "MfgOrderComponent_moId_idx" ON "MfgOrderComponent"("moId");

-- CreateIndex
CREATE INDEX "MfgWorkOrder_moId_idx" ON "MfgWorkOrder"("moId");

-- CreateIndex
CREATE UNIQUE INDEX "MfgWorkOrder_moId_sequence_key" ON "MfgWorkOrder"("moId", "sequence");

-- CreateIndex
CREATE INDEX "MfgScrap_productId_date_idx" ON "MfgScrap"("productId", "date");

-- AddForeignKey
ALTER TABLE "MfgProduct" ADD CONSTRAINT "MfgProduct_categoryId_fkey" FOREIGN KEY ("categoryId") REFERENCES "MfgCategory"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MfgProduct" ADD CONSTRAINT "MfgProduct_uomId_fkey" FOREIGN KEY ("uomId") REFERENCES "MfgUom"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MfgBom" ADD CONSTRAINT "MfgBom_productId_fkey" FOREIGN KEY ("productId") REFERENCES "MfgProduct"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MfgBom" ADD CONSTRAINT "MfgBom_uomId_fkey" FOREIGN KEY ("uomId") REFERENCES "MfgUom"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MfgBomLine" ADD CONSTRAINT "MfgBomLine_bomId_fkey" FOREIGN KEY ("bomId") REFERENCES "MfgBom"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MfgBomLine" ADD CONSTRAINT "MfgBomLine_componentId_fkey" FOREIGN KEY ("componentId") REFERENCES "MfgProduct"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MfgBomLine" ADD CONSTRAINT "MfgBomLine_uomId_fkey" FOREIGN KEY ("uomId") REFERENCES "MfgUom"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MfgBomOperation" ADD CONSTRAINT "MfgBomOperation_bomId_fkey" FOREIGN KEY ("bomId") REFERENCES "MfgBom"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MfgBomOperation" ADD CONSTRAINT "MfgBomOperation_workCenterId_fkey" FOREIGN KEY ("workCenterId") REFERENCES "MfgWorkCenter"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MfgBomByproduct" ADD CONSTRAINT "MfgBomByproduct_bomId_fkey" FOREIGN KEY ("bomId") REFERENCES "MfgBom"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MfgBomByproduct" ADD CONSTRAINT "MfgBomByproduct_productId_fkey" FOREIGN KEY ("productId") REFERENCES "MfgProduct"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MfgLot" ADD CONSTRAINT "MfgLot_productId_fkey" FOREIGN KEY ("productId") REFERENCES "MfgProduct"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MfgStockQuant" ADD CONSTRAINT "MfgStockQuant_productId_fkey" FOREIGN KEY ("productId") REFERENCES "MfgProduct"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MfgStockQuant" ADD CONSTRAINT "MfgStockQuant_lotId_fkey" FOREIGN KEY ("lotId") REFERENCES "MfgLot"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MfgStockQuant" ADD CONSTRAINT "MfgStockQuant_locationId_fkey" FOREIGN KEY ("locationId") REFERENCES "MfgLocation"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MfgStockMove" ADD CONSTRAINT "MfgStockMove_productId_fkey" FOREIGN KEY ("productId") REFERENCES "MfgProduct"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MfgStockMove" ADD CONSTRAINT "MfgStockMove_lotId_fkey" FOREIGN KEY ("lotId") REFERENCES "MfgLot"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MfgStockMove" ADD CONSTRAINT "MfgStockMove_uomId_fkey" FOREIGN KEY ("uomId") REFERENCES "MfgUom"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MfgStockMove" ADD CONSTRAINT "MfgStockMove_srcLocationId_fkey" FOREIGN KEY ("srcLocationId") REFERENCES "MfgLocation"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MfgStockMove" ADD CONSTRAINT "MfgStockMove_destLocationId_fkey" FOREIGN KEY ("destLocationId") REFERENCES "MfgLocation"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MfgOrder" ADD CONSTRAINT "MfgOrder_productId_fkey" FOREIGN KEY ("productId") REFERENCES "MfgProduct"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MfgOrder" ADD CONSTRAINT "MfgOrder_bomId_fkey" FOREIGN KEY ("bomId") REFERENCES "MfgBom"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MfgOrder" ADD CONSTRAINT "MfgOrder_uomId_fkey" FOREIGN KEY ("uomId") REFERENCES "MfgUom"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MfgOrder" ADD CONSTRAINT "MfgOrder_lotId_fkey" FOREIGN KEY ("lotId") REFERENCES "MfgLot"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MfgOrderComponent" ADD CONSTRAINT "MfgOrderComponent_moId_fkey" FOREIGN KEY ("moId") REFERENCES "MfgOrder"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MfgOrderComponent" ADD CONSTRAINT "MfgOrderComponent_productId_fkey" FOREIGN KEY ("productId") REFERENCES "MfgProduct"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MfgOrderComponent" ADD CONSTRAINT "MfgOrderComponent_uomId_fkey" FOREIGN KEY ("uomId") REFERENCES "MfgUom"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MfgWorkOrder" ADD CONSTRAINT "MfgWorkOrder_moId_fkey" FOREIGN KEY ("moId") REFERENCES "MfgOrder"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MfgWorkOrder" ADD CONSTRAINT "MfgWorkOrder_bomOperationId_fkey" FOREIGN KEY ("bomOperationId") REFERENCES "MfgBomOperation"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MfgWorkOrder" ADD CONSTRAINT "MfgWorkOrder_workCenterId_fkey" FOREIGN KEY ("workCenterId") REFERENCES "MfgWorkCenter"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MfgScrap" ADD CONSTRAINT "MfgScrap_productId_fkey" FOREIGN KEY ("productId") REFERENCES "MfgProduct"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MfgScrap" ADD CONSTRAINT "MfgScrap_lotId_fkey" FOREIGN KEY ("lotId") REFERENCES "MfgLot"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MfgScrap" ADD CONSTRAINT "MfgScrap_uomId_fkey" FOREIGN KEY ("uomId") REFERENCES "MfgUom"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MfgScrap" ADD CONSTRAINT "MfgScrap_locationId_fkey" FOREIGN KEY ("locationId") REFERENCES "MfgLocation"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MfgScrap" ADD CONSTRAINT "MfgScrap_moId_fkey" FOREIGN KEY ("moId") REFERENCES "MfgOrder"("id") ON DELETE SET NULL ON UPDATE CASCADE;
