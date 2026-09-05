-- Staff action trail (one shared admin login → the log says who did what).
CREATE TABLE "AuditLog" (
    "id" TEXT NOT NULL,
    "at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "userId" TEXT,
    "email" TEXT,
    "role" TEXT,
    "method" TEXT NOT NULL,
    "path" TEXT NOT NULL,
    "status" INTEGER NOT NULL,
    "ip" TEXT,
    "userAgent" TEXT,
    "requestId" TEXT,
    "durationMs" INTEGER,
    "body" JSONB,

    CONSTRAINT "AuditLog_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "AuditLog_at_idx" ON "AuditLog"("at");
CREATE INDEX "AuditLog_userId_at_idx" ON "AuditLog"("userId", "at");
