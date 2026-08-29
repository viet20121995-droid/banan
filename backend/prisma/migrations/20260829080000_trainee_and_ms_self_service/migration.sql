-- TRAINEE role (internal-ops learner) + public MS link generator fields.
-- Additive only: existing rows keep working, old assignments read as ADMIN.

ALTER TYPE "Role" ADD VALUE IF NOT EXISTS 'TRAINEE';

CREATE TYPE "MsAssignmentSource" AS ENUM ('ADMIN', 'EMPLOYEE_SELF_SERVICE');

ALTER TABLE "MsAssignment" ADD COLUMN "source" "MsAssignmentSource" NOT NULL DEFAULT 'ADMIN';
ALTER TABLE "MsAssignment" ADD COLUMN "requesterName" TEXT;
ALTER TABLE "MsAssignment" ADD COLUMN "requesterEmployeeCode" TEXT;
ALTER TABLE "MsAssignment" ADD COLUMN "requesterNote" TEXT;
ALTER TABLE "MsAssignment" ADD COLUMN "selfServiceKey" TEXT;
CREATE UNIQUE INDEX "MsAssignment_selfServiceKey_key" ON "MsAssignment"("selfServiceKey");

-- userId was already a nullable column; it now links a login account 1:1.
CREATE UNIQUE INDEX "InternalPerson_userId_key" ON "InternalPerson"("userId");
