-- DropForeignKey
ALTER TABLE "MfgReservation" DROP CONSTRAINT "MfgReservation_quantId_fkey";

-- AddForeignKey
ALTER TABLE "MfgReservation" ADD CONSTRAINT "MfgReservation_quantId_fkey" FOREIGN KEY ("quantId") REFERENCES "MfgStockQuant"("id") ON DELETE CASCADE ON UPDATE CASCADE;
