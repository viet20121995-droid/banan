-- AlterTable
ALTER TABLE "User" ADD COLUMN     "marketingOptIn" BOOLEAN NOT NULL DEFAULT true,
ADD COLUMN     "orderUpdatesOptIn" BOOLEAN NOT NULL DEFAULT true;

-- CreateTable
CREATE TABLE "EmailChange" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "newEmail" TEXT NOT NULL,
    "tokenHash" TEXT NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "usedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "EmailChange_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "EmailChange_tokenHash_key" ON "EmailChange"("tokenHash");

-- CreateIndex
CREATE INDEX "EmailChange_userId_idx" ON "EmailChange"("userId");

-- AddForeignKey
ALTER TABLE "EmailChange" ADD CONSTRAINT "EmailChange_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
