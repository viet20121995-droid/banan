-- CreateEnum
CREATE TYPE "QcInspectionStatus" AS ENUM ('DRAFT', 'IN_PROGRESS', 'COMPLETED');

-- CreateEnum
CREATE TYPE "QcOutcome" AS ENUM ('PASS', 'FAIL', 'CRITICAL_FAIL');

-- CreateEnum
CREATE TYPE "QcAnswerValue" AS ENUM ('PASS', 'FAIL', 'NOT_AVAILABLE');

-- CreateEnum
CREATE TYPE "InternalReportDeliveryStatus" AS ENUM ('PENDING', 'PROCESSING', 'SENT', 'FAILED');

-- CreateEnum
CREATE TYPE "MsAssignmentStatus" AS ENUM ('DRAFT', 'ASSIGNED', 'OPENED', 'SUBMITTED', 'NEEDS_REVISION', 'APPROVED', 'REVOKED', 'EXPIRED');

-- CreateEnum
CREATE TYPE "MsAnswerValue" AS ENUM ('YES', 'NO', 'NOT_AVAILABLE');

-- CreateEnum
CREATE TYPE "MsSectionKind" AS ENUM ('SCORED', 'CRITICAL');

-- CreateEnum
CREATE TYPE "MsEvidenceKind" AS ENUM ('RECEIPT', 'PRODUCT', 'PACKAGING', 'ANSWER', 'OTHER');

-- CreateEnum
CREATE TYPE "TrainingCategory" AS ENUM ('PHA_CHE', 'CHE_BIEN', 'ATVSTP', 'QUY_DINH', 'DICH_VU_KHACH_HANG');

-- CreateEnum
CREATE TYPE "TrainingMaterialKind" AS ENUM ('FILE', 'VIDEO', 'LINK');

-- CreateEnum
CREATE TYPE "TrainingProgressStatus" AS ENUM ('NOT_STARTED', 'IN_PROGRESS', 'COMPLETED', 'EXPIRED');

-- CreateEnum
CREATE TYPE "WorkScheduleStatus" AS ENUM ('DRAFT', 'PUBLISHED', 'ARCHIVED');

-- CreateTable
CREATE TABLE "QcTemplate" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "version" INTEGER NOT NULL,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "QcTemplate_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "QcSection" (
    "id" TEXT NOT NULL,
    "templateId" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "sortOrder" INTEGER NOT NULL,
    "isRisk" BOOLEAN NOT NULL DEFAULT false,

    CONSTRAINT "QcSection_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "QcItem" (
    "id" TEXT NOT NULL,
    "sectionId" TEXT NOT NULL,
    "text" TEXT NOT NULL,
    "sortOrder" INTEGER NOT NULL,
    "sourceRef" TEXT,

    CONSTRAINT "QcItem_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "QcInspection" (
    "id" TEXT NOT NULL,
    "templateId" TEXT NOT NULL,
    "storeId" TEXT NOT NULL,
    "inspectionDate" TIMESTAMP(3) NOT NULL,
    "startedAt" TIMESTAMP(3),
    "endedAt" TIMESTAMP(3),
    "staffOnShift" TEXT,
    "inspectorName" TEXT NOT NULL,
    "generalNotes" TEXT,
    "status" "QcInspectionStatus" NOT NULL DEFAULT 'DRAFT',
    "completedAt" TIMESTAMP(3),
    "revision" INTEGER NOT NULL DEFAULT 0,
    "outcome" "QcOutcome",
    "overallPercent" DOUBLE PRECISION,
    "createdById" TEXT NOT NULL,
    "updatedById" TEXT,
    "completedById" TEXT,
    "reopenedById" TEXT,
    "reopenedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "QcInspection_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "QcInspectionAnswer" (
    "id" TEXT NOT NULL,
    "inspectionId" TEXT NOT NULL,
    "itemId" TEXT NOT NULL,
    "value" "QcAnswerValue",
    "failDetail" TEXT,
    "naReason" TEXT,

    CONSTRAINT "QcInspectionAnswer_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "QcRiskAnswer" (
    "id" TEXT NOT NULL,
    "inspectionId" TEXT NOT NULL,
    "itemId" TEXT NOT NULL,
    "occurred" BOOLEAN,
    "detail" TEXT,

    CONSTRAINT "QcRiskAnswer_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "QcEvidence" (
    "id" TEXT NOT NULL,
    "answerId" TEXT,
    "riskAnswerId" TEXT,
    "url" TEXT NOT NULL,
    "mimeType" TEXT NOT NULL,
    "sizeBytes" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "createdById" TEXT,

    CONSTRAINT "QcEvidence_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "QcReportDelivery" (
    "id" TEXT NOT NULL,
    "inspectionId" TEXT NOT NULL,
    "revision" INTEGER NOT NULL,
    "recipients" TEXT[],
    "status" "InternalReportDeliveryStatus" NOT NULL DEFAULT 'PENDING',
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "lockedUntil" TIMESTAMP(3),
    "claimToken" TEXT,
    "reportSnapshot" JSONB NOT NULL,
    "lastError" TEXT,
    "sentAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "QcReportDelivery_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MsTemplate" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "version" INTEGER NOT NULL,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "MsTemplate_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MsSection" (
    "id" TEXT NOT NULL,
    "templateId" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "kind" "MsSectionKind" NOT NULL DEFAULT 'SCORED',
    "weight" INTEGER NOT NULL,
    "sortOrder" INTEGER NOT NULL,

    CONSTRAINT "MsSection_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MsQuestion" (
    "id" TEXT NOT NULL,
    "sectionId" TEXT NOT NULL,
    "text" TEXT NOT NULL,
    "sortOrder" INTEGER NOT NULL,
    "allowNa" BOOLEAN NOT NULL DEFAULT false,

    CONSTRAINT "MsQuestion_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MsAssignment" (
    "id" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "templateId" TEXT NOT NULL,
    "storeId" TEXT NOT NULL,
    "windowStart" TIMESTAMP(3),
    "windowEnd" TIMESTAMP(3),
    "scenario" TEXT,
    "productsToBuy" TEXT,
    "budgetVnd" INTEGER,
    "brief" TEXT,
    "deadline" TIMESTAMP(3),
    "internalNotes" TEXT,
    "status" "MsAssignmentStatus" NOT NULL DEFAULT 'DRAFT',
    "revisionNote" TEXT,
    "firstOpenedAt" TIMESTAMP(3),
    "approvedRevision" INTEGER NOT NULL DEFAULT 0,
    "approvedAt" TIMESTAMP(3),
    "approvedById" TEXT,
    "createdById" TEXT NOT NULL,
    "updatedById" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "MsAssignment_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MsAccessToken" (
    "id" TEXT NOT NULL,
    "assignmentId" TEXT NOT NULL,
    "tokenHash" TEXT NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "revokedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "createdById" TEXT,

    CONSTRAINT "MsAccessToken_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MsSubmission" (
    "id" TEXT NOT NULL,
    "assignmentId" TEXT NOT NULL,
    "submittedAt" TIMESTAMP(3),
    "enteredAt" TIMESTAMP(3),
    "greetedAt" TIMESTAMP(3),
    "orderStartAt" TIMESTAMP(3),
    "paidAt" TIMESTAMP(3),
    "receivedAt" TIMESTAMP(3),
    "productsBought" TEXT,
    "amountPaidVnd" INTEGER,
    "staffName" TEXT,
    "overallComment" TEXT,
    "criticalFail" BOOLEAN NOT NULL DEFAULT false,
    "totalScore" DOUBLE PRECISION,
    "sectionScores" JSONB,

    CONSTRAINT "MsSubmission_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MsAnswer" (
    "id" TEXT NOT NULL,
    "submissionId" TEXT NOT NULL,
    "questionId" TEXT NOT NULL,
    "value" "MsAnswerValue",
    "note" TEXT,

    CONSTRAINT "MsAnswer_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MsEvidence" (
    "id" TEXT NOT NULL,
    "submissionId" TEXT NOT NULL,
    "answerId" TEXT,
    "kind" "MsEvidenceKind" NOT NULL DEFAULT 'OTHER',
    "url" TEXT NOT NULL,
    "mimeType" TEXT NOT NULL,
    "sizeBytes" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "MsEvidence_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MsReportDelivery" (
    "id" TEXT NOT NULL,
    "assignmentId" TEXT NOT NULL,
    "revision" INTEGER NOT NULL,
    "recipients" TEXT[],
    "status" "InternalReportDeliveryStatus" NOT NULL DEFAULT 'PENDING',
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "lockedUntil" TIMESTAMP(3),
    "claimToken" TEXT,
    "reportSnapshot" JSONB NOT NULL,
    "lastError" TEXT,
    "sentAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "MsReportDelivery_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "InternalPerson" (
    "id" TEXT NOT NULL,
    "fullName" TEXT NOT NULL,
    "storeId" TEXT NOT NULL,
    "position" TEXT NOT NULL,
    "startDate" TIMESTAMP(3),
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "notes" TEXT,
    "userId" TEXT,
    "createdById" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "InternalPerson_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "InternalPersonTransfer" (
    "id" TEXT NOT NULL,
    "personId" TEXT NOT NULL,
    "fromStoreId" TEXT,
    "toStoreId" TEXT NOT NULL,
    "changedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "changedById" TEXT,

    CONSTRAINT "InternalPersonTransfer_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "TrainingMaterial" (
    "id" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "category" "TrainingCategory" NOT NULL,
    "kind" "TrainingMaterialKind" NOT NULL,
    "url" TEXT,
    "version" INTEGER NOT NULL DEFAULT 1,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "isRequired" BOOLEAN NOT NULL DEFAULT false,
    "estimatedMinutes" INTEGER,
    "effectiveFrom" TIMESTAMP(3),
    "supersedesId" TEXT,
    "createdById" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "TrainingMaterial_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "TrainingPath" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "position" TEXT,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdById" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "TrainingPath_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "TrainingPathItem" (
    "id" TEXT NOT NULL,
    "pathId" TEXT NOT NULL,
    "materialId" TEXT NOT NULL,
    "sortOrder" INTEGER NOT NULL,
    "isRequired" BOOLEAN NOT NULL DEFAULT true,
    "dueDays" INTEGER,

    CONSTRAINT "TrainingPathItem_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "TrainingAssignment" (
    "id" TEXT NOT NULL,
    "personId" TEXT NOT NULL,
    "pathId" TEXT NOT NULL,
    "startDate" TIMESTAMP(3) NOT NULL,
    "assignedById" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "TrainingAssignment_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "TrainingProgress" (
    "id" TEXT NOT NULL,
    "assignmentId" TEXT NOT NULL,
    "pathItemId" TEXT NOT NULL,
    "status" "TrainingProgressStatus" NOT NULL DEFAULT 'NOT_STARTED',
    "completedAt" TIMESTAMP(3),
    "confirmedById" TEXT,
    "quizScore" INTEGER,
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "notes" TEXT,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "TrainingProgress_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "WorkSchedule" (
    "id" TEXT NOT NULL,
    "weekStart" TIMESTAMP(3) NOT NULL,
    "status" "WorkScheduleStatus" NOT NULL DEFAULT 'DRAFT',
    "revision" INTEGER NOT NULL DEFAULT 0,
    "notes" TEXT,
    "publishedAt" TIMESTAMP(3),
    "publishedById" TEXT,
    "createdById" TEXT NOT NULL,
    "updatedById" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "WorkSchedule_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "WorkScheduleShift" (
    "id" TEXT NOT NULL,
    "scheduleId" TEXT NOT NULL,
    "storeId" TEXT NOT NULL,
    "label" TEXT NOT NULL,
    "startTime" TEXT NOT NULL,
    "endTime" TEXT NOT NULL,
    "sortOrder" INTEGER NOT NULL,

    CONSTRAINT "WorkScheduleShift_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "WorkScheduleAssignment" (
    "id" TEXT NOT NULL,
    "shiftId" TEXT NOT NULL,
    "dayOfWeek" INTEGER NOT NULL,
    "personId" TEXT,
    "freeName" TEXT,
    "note" TEXT,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "WorkScheduleAssignment_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "WorkSchedulePublish" (
    "id" TEXT NOT NULL,
    "scheduleId" TEXT NOT NULL,
    "revision" INTEGER NOT NULL,
    "snapshot" JSONB NOT NULL,
    "publishedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "publishedById" TEXT,

    CONSTRAINT "WorkSchedulePublish_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "QcTemplate_name_version_key" ON "QcTemplate"("name", "version");

-- CreateIndex
CREATE UNIQUE INDEX "QcSection_templateId_sortOrder_key" ON "QcSection"("templateId", "sortOrder");

-- CreateIndex
CREATE UNIQUE INDEX "QcItem_sectionId_sortOrder_key" ON "QcItem"("sectionId", "sortOrder");

-- CreateIndex
CREATE INDEX "QcInspection_storeId_inspectionDate_idx" ON "QcInspection"("storeId", "inspectionDate");

-- CreateIndex
CREATE INDEX "QcInspection_status_idx" ON "QcInspection"("status");

-- CreateIndex
CREATE UNIQUE INDEX "QcInspectionAnswer_inspectionId_itemId_key" ON "QcInspectionAnswer"("inspectionId", "itemId");

-- CreateIndex
CREATE UNIQUE INDEX "QcRiskAnswer_inspectionId_itemId_key" ON "QcRiskAnswer"("inspectionId", "itemId");

-- CreateIndex
CREATE INDEX "QcReportDelivery_status_idx" ON "QcReportDelivery"("status");

-- CreateIndex
CREATE UNIQUE INDEX "QcReportDelivery_inspectionId_revision_key" ON "QcReportDelivery"("inspectionId", "revision");

-- CreateIndex
CREATE UNIQUE INDEX "MsTemplate_name_version_key" ON "MsTemplate"("name", "version");

-- CreateIndex
CREATE UNIQUE INDEX "MsSection_templateId_sortOrder_key" ON "MsSection"("templateId", "sortOrder");

-- CreateIndex
CREATE UNIQUE INDEX "MsQuestion_sectionId_sortOrder_key" ON "MsQuestion"("sectionId", "sortOrder");

-- CreateIndex
CREATE UNIQUE INDEX "MsAssignment_code_key" ON "MsAssignment"("code");

-- CreateIndex
CREATE INDEX "MsAssignment_storeId_status_idx" ON "MsAssignment"("storeId", "status");

-- CreateIndex
CREATE INDEX "MsAssignment_status_idx" ON "MsAssignment"("status");

-- CreateIndex
CREATE UNIQUE INDEX "MsAccessToken_tokenHash_key" ON "MsAccessToken"("tokenHash");

-- CreateIndex
CREATE INDEX "MsAccessToken_assignmentId_idx" ON "MsAccessToken"("assignmentId");

-- CreateIndex
CREATE UNIQUE INDEX "MsSubmission_assignmentId_key" ON "MsSubmission"("assignmentId");

-- CreateIndex
CREATE UNIQUE INDEX "MsAnswer_submissionId_questionId_key" ON "MsAnswer"("submissionId", "questionId");

-- CreateIndex
CREATE INDEX "MsReportDelivery_status_idx" ON "MsReportDelivery"("status");

-- CreateIndex
CREATE UNIQUE INDEX "MsReportDelivery_assignmentId_revision_key" ON "MsReportDelivery"("assignmentId", "revision");

-- CreateIndex
CREATE INDEX "InternalPerson_storeId_isActive_idx" ON "InternalPerson"("storeId", "isActive");

-- CreateIndex
CREATE INDEX "InternalPersonTransfer_personId_changedAt_idx" ON "InternalPersonTransfer"("personId", "changedAt");

-- CreateIndex
CREATE INDEX "TrainingMaterial_category_isActive_idx" ON "TrainingMaterial"("category", "isActive");

-- CreateIndex
CREATE UNIQUE INDEX "TrainingPathItem_pathId_sortOrder_key" ON "TrainingPathItem"("pathId", "sortOrder");

-- CreateIndex
CREATE UNIQUE INDEX "TrainingAssignment_personId_pathId_key" ON "TrainingAssignment"("personId", "pathId");

-- CreateIndex
CREATE UNIQUE INDEX "TrainingProgress_assignmentId_pathItemId_key" ON "TrainingProgress"("assignmentId", "pathItemId");

-- CreateIndex
CREATE UNIQUE INDEX "WorkSchedule_weekStart_key" ON "WorkSchedule"("weekStart");

-- CreateIndex
CREATE INDEX "WorkScheduleShift_scheduleId_storeId_idx" ON "WorkScheduleShift"("scheduleId", "storeId");

-- CreateIndex
CREATE INDEX "WorkScheduleAssignment_shiftId_dayOfWeek_idx" ON "WorkScheduleAssignment"("shiftId", "dayOfWeek");

-- CreateIndex
CREATE UNIQUE INDEX "WorkSchedulePublish_scheduleId_revision_key" ON "WorkSchedulePublish"("scheduleId", "revision");

-- AddForeignKey
ALTER TABLE "QcSection" ADD CONSTRAINT "QcSection_templateId_fkey" FOREIGN KEY ("templateId") REFERENCES "QcTemplate"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "QcItem" ADD CONSTRAINT "QcItem_sectionId_fkey" FOREIGN KEY ("sectionId") REFERENCES "QcSection"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "QcInspection" ADD CONSTRAINT "QcInspection_templateId_fkey" FOREIGN KEY ("templateId") REFERENCES "QcTemplate"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "QcInspection" ADD CONSTRAINT "QcInspection_storeId_fkey" FOREIGN KEY ("storeId") REFERENCES "Store"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "QcInspectionAnswer" ADD CONSTRAINT "QcInspectionAnswer_inspectionId_fkey" FOREIGN KEY ("inspectionId") REFERENCES "QcInspection"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "QcInspectionAnswer" ADD CONSTRAINT "QcInspectionAnswer_itemId_fkey" FOREIGN KEY ("itemId") REFERENCES "QcItem"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "QcRiskAnswer" ADD CONSTRAINT "QcRiskAnswer_inspectionId_fkey" FOREIGN KEY ("inspectionId") REFERENCES "QcInspection"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "QcRiskAnswer" ADD CONSTRAINT "QcRiskAnswer_itemId_fkey" FOREIGN KEY ("itemId") REFERENCES "QcItem"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "QcEvidence" ADD CONSTRAINT "QcEvidence_answerId_fkey" FOREIGN KEY ("answerId") REFERENCES "QcInspectionAnswer"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "QcEvidence" ADD CONSTRAINT "QcEvidence_riskAnswerId_fkey" FOREIGN KEY ("riskAnswerId") REFERENCES "QcRiskAnswer"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "QcReportDelivery" ADD CONSTRAINT "QcReportDelivery_inspectionId_fkey" FOREIGN KEY ("inspectionId") REFERENCES "QcInspection"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MsSection" ADD CONSTRAINT "MsSection_templateId_fkey" FOREIGN KEY ("templateId") REFERENCES "MsTemplate"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MsQuestion" ADD CONSTRAINT "MsQuestion_sectionId_fkey" FOREIGN KEY ("sectionId") REFERENCES "MsSection"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MsAssignment" ADD CONSTRAINT "MsAssignment_templateId_fkey" FOREIGN KEY ("templateId") REFERENCES "MsTemplate"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MsAssignment" ADD CONSTRAINT "MsAssignment_storeId_fkey" FOREIGN KEY ("storeId") REFERENCES "Store"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MsAccessToken" ADD CONSTRAINT "MsAccessToken_assignmentId_fkey" FOREIGN KEY ("assignmentId") REFERENCES "MsAssignment"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MsSubmission" ADD CONSTRAINT "MsSubmission_assignmentId_fkey" FOREIGN KEY ("assignmentId") REFERENCES "MsAssignment"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MsAnswer" ADD CONSTRAINT "MsAnswer_submissionId_fkey" FOREIGN KEY ("submissionId") REFERENCES "MsSubmission"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MsAnswer" ADD CONSTRAINT "MsAnswer_questionId_fkey" FOREIGN KEY ("questionId") REFERENCES "MsQuestion"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MsEvidence" ADD CONSTRAINT "MsEvidence_submissionId_fkey" FOREIGN KEY ("submissionId") REFERENCES "MsSubmission"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MsEvidence" ADD CONSTRAINT "MsEvidence_answerId_fkey" FOREIGN KEY ("answerId") REFERENCES "MsAnswer"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MsReportDelivery" ADD CONSTRAINT "MsReportDelivery_assignmentId_fkey" FOREIGN KEY ("assignmentId") REFERENCES "MsAssignment"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "InternalPerson" ADD CONSTRAINT "InternalPerson_storeId_fkey" FOREIGN KEY ("storeId") REFERENCES "Store"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "InternalPersonTransfer" ADD CONSTRAINT "InternalPersonTransfer_personId_fkey" FOREIGN KEY ("personId") REFERENCES "InternalPerson"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TrainingPathItem" ADD CONSTRAINT "TrainingPathItem_pathId_fkey" FOREIGN KEY ("pathId") REFERENCES "TrainingPath"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TrainingPathItem" ADD CONSTRAINT "TrainingPathItem_materialId_fkey" FOREIGN KEY ("materialId") REFERENCES "TrainingMaterial"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TrainingAssignment" ADD CONSTRAINT "TrainingAssignment_personId_fkey" FOREIGN KEY ("personId") REFERENCES "InternalPerson"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TrainingAssignment" ADD CONSTRAINT "TrainingAssignment_pathId_fkey" FOREIGN KEY ("pathId") REFERENCES "TrainingPath"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TrainingProgress" ADD CONSTRAINT "TrainingProgress_assignmentId_fkey" FOREIGN KEY ("assignmentId") REFERENCES "TrainingAssignment"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TrainingProgress" ADD CONSTRAINT "TrainingProgress_pathItemId_fkey" FOREIGN KEY ("pathItemId") REFERENCES "TrainingPathItem"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "WorkScheduleShift" ADD CONSTRAINT "WorkScheduleShift_scheduleId_fkey" FOREIGN KEY ("scheduleId") REFERENCES "WorkSchedule"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "WorkScheduleShift" ADD CONSTRAINT "WorkScheduleShift_storeId_fkey" FOREIGN KEY ("storeId") REFERENCES "Store"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "WorkScheduleAssignment" ADD CONSTRAINT "WorkScheduleAssignment_shiftId_fkey" FOREIGN KEY ("shiftId") REFERENCES "WorkScheduleShift"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "WorkScheduleAssignment" ADD CONSTRAINT "WorkScheduleAssignment_personId_fkey" FOREIGN KEY ("personId") REFERENCES "InternalPerson"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "WorkSchedulePublish" ADD CONSTRAINT "WorkSchedulePublish_scheduleId_fkey" FOREIGN KEY ("scheduleId") REFERENCES "WorkSchedule"("id") ON DELETE CASCADE ON UPDATE CASCADE;

