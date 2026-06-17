-- Hard idempotency for refund requests: at most ONE non-REJECTED refund per
-- (orderId, paymentId). This lets the cancel path (creates the row inside the
-- cancel transaction) and the late-capture auto-refund (runs standalone after
-- the order is already CANCELLED) coexist race-free — a duplicate insert hits
-- this index and is handled idempotently by the caller. REJECTED rows are
-- excluded so a fresh request is still possible after a rejection.
--
-- Expressed as a raw partial index because Prisma can't model a filtered
-- unique constraint in schema.prisma.
--
-- DEFENSIVE: before this commit there was no hard constraint, and a race
-- (cancel path vs late-capture auto-refund) could have left two non-REJECTED
-- refunds for the same (orderId, paymentId). Creating the unique index on such
-- data would fail and block the container from booting. So first resolve any
-- pre-existing duplicates: keep the most-progressed (then earliest) refund per
-- (orderId, paymentId) and mark the rest REJECTED (non-destructive — preserves
-- the rows for audit and excludes them from the partial unique).
WITH ranked AS (
  SELECT
    id,
    ROW_NUMBER() OVER (
      PARTITION BY "orderId", "paymentId"
      ORDER BY
        CASE status
          WHEN 'COMPLETED'  THEN 0
          WHEN 'PROCESSING' THEN 1
          WHEN 'APPROVED'   THEN 2
          WHEN 'REQUESTED'  THEN 3
          ELSE 4
        END,
        "createdAt" ASC
    ) AS rn
  FROM "Refund"
  WHERE "paymentId" IS NOT NULL
    AND status <> 'REJECTED'::"RefundStatus"
)
UPDATE "Refund" r
  SET status = 'REJECTED'::"RefundStatus",
      reason = COALESCE(r.reason, '') || ' [auto-rejected: duplicate active refund]'
  FROM ranked
  WHERE r.id = ranked.id
    AND ranked.rn > 1;

CREATE UNIQUE INDEX IF NOT EXISTS "Refund_orderId_paymentId_active_key"
  ON "Refund" ("orderId", "paymentId")
  WHERE "paymentId" IS NOT NULL AND status <> 'REJECTED'::"RefundStatus";
