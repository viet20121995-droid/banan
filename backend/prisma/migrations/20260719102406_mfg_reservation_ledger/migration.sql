-- CreateTable
CREATE TABLE "MfgReservation" (
    "id" TEXT NOT NULL,
    "moId" TEXT NOT NULL,
    "quantId" TEXT NOT NULL,
    "productId" TEXT NOT NULL,
    "qty" DECIMAL(14,3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "MfgReservation_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "MfgReservation_moId_idx" ON "MfgReservation"("moId");

-- CreateIndex
CREATE INDEX "MfgReservation_quantId_idx" ON "MfgReservation"("quantId");

-- AddForeignKey
ALTER TABLE "MfgReservation" ADD CONSTRAINT "MfgReservation_moId_fkey" FOREIGN KEY ("moId") REFERENCES "MfgOrder"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MfgReservation" ADD CONSTRAINT "MfgReservation_quantId_fkey" FOREIGN KEY ("quantId") REFERENCES "MfgStockQuant"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
