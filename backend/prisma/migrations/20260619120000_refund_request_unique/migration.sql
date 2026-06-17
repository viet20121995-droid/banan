-- Hard idempotency for refund requests: at most ONE non-REJECTED refund per
-- (orderId, paymentId). This lets the cancel path (creates the row inside the
-- cancel transaction) and the late-capture auto-refund (runs standalone after
-- the order is already CANCELLED) coexist race-free — a duplicate insert hits
-- this index and is handled idempotently by the caller. REJECTED rows are
-- excluded so a fresh request is still possible after a rejection.
--
-- Expressed as a raw partial index because Prisma can't model a filtered
-- unique constraint in schema.prisma. Safe to add: createRequest already
-- de-duplicates in-flight refunds, so no existing duplicates should violate it.
CREATE UNIQUE INDEX IF NOT EXISTS "Refund_orderId_paymentId_active_key"
  ON "Refund" ("orderId", "paymentId")
  WHERE "paymentId" IS NOT NULL AND status <> 'REJECTED'::"RefundStatus";
