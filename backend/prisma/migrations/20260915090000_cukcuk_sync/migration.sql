-- CukCuk POS sync tables (internal ops app).
CREATE TABLE "CukcukRecord" (
    "id" TEXT NOT NULL,
    "kind" TEXT NOT NULL,
    "externalId" TEXT NOT NULL,
    "label" TEXT,
    "branchId" TEXT,
    "modifiedAt" TIMESTAMP(3),
    "search" TEXT,
    "data" JSONB NOT NULL,
    "syncedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "CukcukRecord_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "CukcukRecord_kind_externalId_key" ON "CukcukRecord"("kind", "externalId");
CREATE INDEX "CukcukRecord_kind_modifiedAt_idx" ON "CukcukRecord"("kind", "modifiedAt");

CREATE TABLE "CukcukSync" (
    "id" TEXT NOT NULL,
    "kind" TEXT NOT NULL,
    "startedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "finishedAt" TIMESTAMP(3),
    "ok" BOOLEAN,
    "fetched" INTEGER NOT NULL DEFAULT 0,
    "error" TEXT,
    "startedBy" TEXT,
    CONSTRAINT "CukcukSync_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "CukcukSync_kind_startedAt_idx" ON "CukcukSync"("kind", "startedAt");
