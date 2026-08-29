-- CreateEnum
CREATE TYPE "SurveyTemplateStatus" AS ENUM ('DRAFT', 'PUBLISHED', 'ARCHIVED');

-- CreateEnum
CREATE TYPE "SurveyQuestionType" AS ENUM ('EMOJI_SCALE', 'RATING', 'NPS', 'SINGLE_CHOICE', 'MULTI_CHOICE', 'TEXT', 'YES_NO');

-- CreateEnum
CREATE TYPE "SurveyCaseStatus" AS ENUM ('NEW', 'IN_PROGRESS', 'RESOLVED');

-- CreateEnum
CREATE TYPE "SurveyRewardMode" AS ENUM ('NONE', 'MESSAGE_ONLY', 'VOUCHER_CODE');

-- CreateEnum
CREATE TYPE "SurveyRewardClaimStatus" AS ENUM ('ISSUED', 'REDEEMED', 'EXPIRED', 'VOID');

-- CreateTable
CREATE TABLE "SurveyTemplate" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "version" INTEGER NOT NULL,
    "status" "SurveyTemplateStatus" NOT NULL DEFAULT 'DRAFT',
    "isDefault" BOOLEAN NOT NULL DEFAULT false,
    "publishedAt" TIMESTAMP(3),
    "createdById" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "SurveyTemplate_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "SurveyQuestion" (
    "id" TEXT NOT NULL,
    "templateId" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "type" "SurveyQuestionType" NOT NULL,
    "textVi" TEXT NOT NULL,
    "textEn" TEXT NOT NULL,
    "required" BOOLEAN NOT NULL DEFAULT false,
    "sortOrder" INTEGER NOT NULL,
    "maxLength" INTEGER,
    "showIfQuestionCode" TEXT,
    "showIfOp" TEXT,
    "showIfValue" INTEGER,

    CONSTRAINT "SurveyQuestion_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "SurveyOption" (
    "id" TEXT NOT NULL,
    "questionId" TEXT NOT NULL,
    "value" TEXT NOT NULL,
    "labelVi" TEXT NOT NULL,
    "labelEn" TEXT NOT NULL,
    "sortOrder" INTEGER NOT NULL,

    CONSTRAINT "SurveyOption_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "SurveyResponse" (
    "id" TEXT NOT NULL,
    "templateId" TEXT NOT NULL,
    "storeId" TEXT NOT NULL,
    "storeName" TEXT NOT NULL,
    "overall" INTEGER,
    "nps" INTEGER,
    "comment" TEXT,
    "locale" TEXT NOT NULL DEFAULT 'vi',
    "contactRequested" BOOLEAN NOT NULL DEFAULT false,
    "contactName" TEXT,
    "contactPhone" TEXT,
    "contactConsentAt" TIMESTAMP(3),
    "clientRequestId" TEXT NOT NULL,
    "browserKey" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "SurveyResponse_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "SurveyAnswer" (
    "id" TEXT NOT NULL,
    "responseId" TEXT NOT NULL,
    "questionId" TEXT NOT NULL,
    "questionCode" TEXT NOT NULL,
    "numberValue" INTEGER,
    "textValue" TEXT,
    "optionValues" TEXT[] DEFAULT ARRAY[]::TEXT[],

    CONSTRAINT "SurveyAnswer_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "SurveyCase" (
    "id" TEXT NOT NULL,
    "responseId" TEXT NOT NULL,
    "status" "SurveyCaseStatus" NOT NULL DEFAULT 'NEW',
    "assigneeName" TEXT,
    "note" TEXT,
    "resolvedAt" TIMESTAMP(3),
    "resolvedById" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "SurveyCase_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "SurveyRewardCampaign" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "instructions" TEXT,
    "mode" "SurveyRewardMode" NOT NULL DEFAULT 'NONE',
    "isEnabled" BOOLEAN NOT NULL DEFAULT false,
    "startsAt" TIMESTAMP(3),
    "endsAt" TIMESTAMP(3),
    "expiryDays" INTEGER NOT NULL DEFAULT 7,
    "probabilityPct" INTEGER NOT NULL DEFAULT 100,
    "dailyCap" INTEGER,
    "totalCap" INTEGER,
    "issuedCount" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "SurveyRewardCampaign_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "SurveyRewardClaim" (
    "id" TEXT NOT NULL,
    "campaignId" TEXT NOT NULL,
    "responseId" TEXT NOT NULL,
    "voucherCode" TEXT,
    "status" "SurveyRewardClaimStatus" NOT NULL DEFAULT 'ISSUED',
    "dayKey" TEXT NOT NULL,
    "browserKey" TEXT,
    "expiresAt" TIMESTAMP(3),
    "redeemedAt" TIMESTAMP(3),
    "redeemedById" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "SurveyRewardClaim_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "SurveyAlertDelivery" (
    "id" TEXT NOT NULL,
    "caseId" TEXT NOT NULL,
    "recipients" TEXT[],
    "status" "InternalReportDeliveryStatus" NOT NULL DEFAULT 'PENDING',
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "lockedUntil" TIMESTAMP(3),
    "claimToken" TEXT,
    "snapshot" JSONB NOT NULL,
    "lastError" TEXT,
    "sentAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "SurveyAlertDelivery_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "SurveyTemplate_status_isDefault_idx" ON "SurveyTemplate"("status", "isDefault");

-- CreateIndex
CREATE UNIQUE INDEX "SurveyTemplate_name_version_key" ON "SurveyTemplate"("name", "version");

-- CreateIndex
CREATE UNIQUE INDEX "SurveyQuestion_templateId_code_key" ON "SurveyQuestion"("templateId", "code");

-- CreateIndex
CREATE UNIQUE INDEX "SurveyOption_questionId_value_key" ON "SurveyOption"("questionId", "value");

-- CreateIndex
CREATE UNIQUE INDEX "SurveyResponse_clientRequestId_key" ON "SurveyResponse"("clientRequestId");

-- CreateIndex
CREATE INDEX "SurveyResponse_storeId_createdAt_idx" ON "SurveyResponse"("storeId", "createdAt");

-- CreateIndex
CREATE INDEX "SurveyResponse_createdAt_idx" ON "SurveyResponse"("createdAt");

-- CreateIndex
CREATE INDEX "SurveyAnswer_questionCode_idx" ON "SurveyAnswer"("questionCode");

-- CreateIndex
CREATE UNIQUE INDEX "SurveyAnswer_responseId_questionId_key" ON "SurveyAnswer"("responseId", "questionId");

-- CreateIndex
CREATE UNIQUE INDEX "SurveyCase_responseId_key" ON "SurveyCase"("responseId");

-- CreateIndex
CREATE INDEX "SurveyCase_status_idx" ON "SurveyCase"("status");

-- CreateIndex
CREATE UNIQUE INDEX "SurveyRewardClaim_responseId_key" ON "SurveyRewardClaim"("responseId");

-- CreateIndex
CREATE UNIQUE INDEX "SurveyRewardClaim_voucherCode_key" ON "SurveyRewardClaim"("voucherCode");

-- CreateIndex
CREATE INDEX "SurveyRewardClaim_campaignId_status_idx" ON "SurveyRewardClaim"("campaignId", "status");

-- CreateIndex
CREATE UNIQUE INDEX "SurveyRewardClaim_campaignId_browserKey_dayKey_key" ON "SurveyRewardClaim"("campaignId", "browserKey", "dayKey");

-- CreateIndex
CREATE UNIQUE INDEX "SurveyAlertDelivery_caseId_key" ON "SurveyAlertDelivery"("caseId");

-- CreateIndex
CREATE INDEX "SurveyAlertDelivery_status_idx" ON "SurveyAlertDelivery"("status");

-- AddForeignKey
ALTER TABLE "SurveyQuestion" ADD CONSTRAINT "SurveyQuestion_templateId_fkey" FOREIGN KEY ("templateId") REFERENCES "SurveyTemplate"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SurveyOption" ADD CONSTRAINT "SurveyOption_questionId_fkey" FOREIGN KEY ("questionId") REFERENCES "SurveyQuestion"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SurveyResponse" ADD CONSTRAINT "SurveyResponse_templateId_fkey" FOREIGN KEY ("templateId") REFERENCES "SurveyTemplate"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SurveyResponse" ADD CONSTRAINT "SurveyResponse_storeId_fkey" FOREIGN KEY ("storeId") REFERENCES "Store"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SurveyAnswer" ADD CONSTRAINT "SurveyAnswer_responseId_fkey" FOREIGN KEY ("responseId") REFERENCES "SurveyResponse"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SurveyAnswer" ADD CONSTRAINT "SurveyAnswer_questionId_fkey" FOREIGN KEY ("questionId") REFERENCES "SurveyQuestion"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SurveyCase" ADD CONSTRAINT "SurveyCase_responseId_fkey" FOREIGN KEY ("responseId") REFERENCES "SurveyResponse"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SurveyRewardClaim" ADD CONSTRAINT "SurveyRewardClaim_campaignId_fkey" FOREIGN KEY ("campaignId") REFERENCES "SurveyRewardCampaign"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SurveyRewardClaim" ADD CONSTRAINT "SurveyRewardClaim_responseId_fkey" FOREIGN KEY ("responseId") REFERENCES "SurveyResponse"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SurveyAlertDelivery" ADD CONSTRAINT "SurveyAlertDelivery_caseId_fkey" FOREIGN KEY ("caseId") REFERENCES "SurveyCase"("id") ON DELETE CASCADE ON UPDATE CASCADE;
