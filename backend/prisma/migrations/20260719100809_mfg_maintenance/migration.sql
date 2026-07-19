-- CreateEnum
CREATE TYPE "MfgMaintenanceType" AS ENUM ('PREVENTIVE', 'CORRECTIVE');

-- CreateEnum
CREATE TYPE "MfgMaintenanceState" AS ENUM ('PLANNED', 'DONE');

-- CreateTable
CREATE TABLE "MfgMaintenance" (
    "id" TEXT NOT NULL,
    "workCenterId" TEXT NOT NULL,
    "type" "MfgMaintenanceType" NOT NULL DEFAULT 'PREVENTIVE',
    "state" "MfgMaintenanceState" NOT NULL DEFAULT 'PLANNED',
    "scheduledDate" TIMESTAMP(3) NOT NULL,
    "doneDate" TIMESTAMP(3),
    "downtimeMin" INTEGER NOT NULL DEFAULT 0,
    "note" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "MfgMaintenance_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "MfgMaintenance_workCenterId_state_idx" ON "MfgMaintenance"("workCenterId", "state");

-- CreateIndex
CREATE INDEX "MfgMaintenance_doneDate_idx" ON "MfgMaintenance"("doneDate");

-- AddForeignKey
ALTER TABLE "MfgMaintenance" ADD CONSTRAINT "MfgMaintenance_workCenterId_fkey" FOREIGN KEY ("workCenterId") REFERENCES "MfgWorkCenter"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
