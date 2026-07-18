-- CreateEnum
CREATE TYPE "MfgTestType" AS ENUM ('MEASURE', 'PASS_FAIL');

-- CreateEnum
CREATE TYPE "MfgCheckResult" AS ENUM ('NONE', 'PASS', 'FAIL');

-- CreateEnum
CREATE TYPE "MfgAlertStage" AS ENUM ('NEW', 'CONFIRMED', 'SOLVED');

-- CreateTable
CREATE TABLE "MfgQualityPoint" (
    "id" TEXT NOT NULL,
    "titleVi" TEXT NOT NULL,
    "titleEn" TEXT NOT NULL,
    "testType" "MfgTestType" NOT NULL,
    "bomOperationId" TEXT,
    "productId" TEXT,
    "normMin" DECIMAL(10,2),
    "normMax" DECIMAL(10,2),
    "unit" TEXT,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "MfgQualityPoint_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MfgQualityCheck" (
    "id" TEXT NOT NULL,
    "qualityPointId" TEXT NOT NULL,
    "moId" TEXT,
    "workOrderId" TEXT,
    "result" "MfgCheckResult" NOT NULL DEFAULT 'NONE',
    "measuredValue" DECIMAL(10,2),
    "note" TEXT,
    "userId" TEXT,
    "date" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "MfgQualityCheck_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MfgQualityAlert" (
    "id" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "moId" TEXT,
    "productId" TEXT,
    "stage" "MfgAlertStage" NOT NULL DEFAULT 'NEW',
    "description" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "MfgQualityAlert_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "MfgQualityPoint_bomOperationId_idx" ON "MfgQualityPoint"("bomOperationId");

-- CreateIndex
CREATE INDEX "MfgQualityCheck_workOrderId_idx" ON "MfgQualityCheck"("workOrderId");

-- CreateIndex
CREATE INDEX "MfgQualityCheck_moId_idx" ON "MfgQualityCheck"("moId");

-- CreateIndex
CREATE INDEX "MfgQualityAlert_stage_idx" ON "MfgQualityAlert"("stage");

-- AddForeignKey
ALTER TABLE "MfgQualityPoint" ADD CONSTRAINT "MfgQualityPoint_bomOperationId_fkey" FOREIGN KEY ("bomOperationId") REFERENCES "MfgBomOperation"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MfgQualityPoint" ADD CONSTRAINT "MfgQualityPoint_productId_fkey" FOREIGN KEY ("productId") REFERENCES "MfgProduct"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MfgQualityCheck" ADD CONSTRAINT "MfgQualityCheck_qualityPointId_fkey" FOREIGN KEY ("qualityPointId") REFERENCES "MfgQualityPoint"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MfgQualityCheck" ADD CONSTRAINT "MfgQualityCheck_moId_fkey" FOREIGN KEY ("moId") REFERENCES "MfgOrder"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MfgQualityCheck" ADD CONSTRAINT "MfgQualityCheck_workOrderId_fkey" FOREIGN KEY ("workOrderId") REFERENCES "MfgWorkOrder"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MfgQualityAlert" ADD CONSTRAINT "MfgQualityAlert_moId_fkey" FOREIGN KEY ("moId") REFERENCES "MfgOrder"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MfgQualityAlert" ADD CONSTRAINT "MfgQualityAlert_productId_fkey" FOREIGN KEY ("productId") REFERENCES "MfgProduct"("id") ON DELETE SET NULL ON UPDATE CASCADE;
