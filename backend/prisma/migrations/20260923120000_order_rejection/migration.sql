-- Why a checkout was refused (container logs are lost on every deploy).
CREATE TABLE "OrderRejection" (
  "id" TEXT NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "status" INTEGER NOT NULL,
  "code" TEXT NOT NULL,
  "message" TEXT NOT NULL,
  "userId" TEXT,
  "ip" TEXT,
  "userAgent" TEXT,
  CONSTRAINT "OrderRejection_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "OrderRejection_createdAt_idx" ON "OrderRejection"("createdAt");
