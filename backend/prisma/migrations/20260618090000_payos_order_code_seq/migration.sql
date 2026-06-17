-- Guaranteed-unique numeric orderCode for PayOS payment links. A DB sequence
-- removes the same-millisecond collision risk of timestamp-derived codes
-- (PayOS requires a per-merchant-unique orderCode, and our
-- Payment.[provider, providerRef] unique index would otherwise trip).
--
-- START WITH a value well above any timestamp-based code already issued
-- (Date.now()*1000 ≈ 1.75e15) and far below Number.MAX_SAFE_INTEGER (~9.0e15),
-- so Number(nextval) stays exact in JS.
CREATE SEQUENCE IF NOT EXISTS payos_order_code_seq
  START WITH 2000000000000000
  INCREMENT BY 1;
