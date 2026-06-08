-- CreateTable: sent newsletter campaign history
CREATE TABLE "NewsletterCampaign" (
    "id" TEXT NOT NULL,
    "subject" TEXT NOT NULL,
    "body" TEXT NOT NULL,
    "imageUrl" TEXT,
    "audience" TEXT NOT NULL,
    "alsoInApp" BOOLEAN NOT NULL DEFAULT false,
    "recipients" INTEGER NOT NULL DEFAULT 0,
    "emailsSent" INTEGER NOT NULL DEFAULT 0,
    "inAppSent" INTEGER NOT NULL DEFAULT 0,
    "sentById" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "NewsletterCampaign_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "NewsletterCampaign_createdAt_idx" ON "NewsletterCampaign"("createdAt");
