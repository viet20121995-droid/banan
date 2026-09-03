-- CreateTable
CREATE TABLE "SiteEvent" (
    "id" TEXT NOT NULL,
    "visitorId" TEXT NOT NULL,
    "sessionId" TEXT NOT NULL,
    "type" TEXT NOT NULL,
    "path" TEXT NOT NULL,
    "label" TEXT,
    "value" INTEGER,
    "device" TEXT,
    "referrer" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "SiteEvent_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "SiteEvent_createdAt_idx" ON "SiteEvent"("createdAt");

-- CreateIndex
CREATE INDEX "SiteEvent_type_createdAt_idx" ON "SiteEvent"("type", "createdAt");
