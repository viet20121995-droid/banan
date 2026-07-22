-- Atomic, readable PO numbering (replaces the racy count()+1). Seeded past
-- any existing PO-<n> row so legacy codes can never collide with new ones.
CREATE SEQUENCE "MfgPurchaseOrder_code_seq" START WITH 1;
SELECT setval(
  '"MfgPurchaseOrder_code_seq"',
  GREATEST(1, (
    SELECT COALESCE(MAX(NULLIF(regexp_replace("code", '\D', '', 'g'), '')::bigint), 0) + 1
    FROM "MfgPurchaseOrder"
  )),
  false
);
