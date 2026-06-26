-- Switch the active online payment provider from PayOS to 9Pay (9pay.vn).
-- The PAYOS value is intentionally kept: Postgres can't drop an enum value
-- safely and removing it would require recreating the type (and would break any
-- historical Payment rows). No new rows will use PAYOS.
ALTER TYPE "PaymentProvider" ADD VALUE IF NOT EXISTS 'NINEPAY';

-- Guaranteed-unique numeric invoice_no for 9Pay payment links. A DB sequence
-- removes the same-millisecond collision risk of timestamp-derived codes
-- (9Pay requires a per-merchant-unique invoice_no, and our
-- Payment.[provider, providerRef] unique index would otherwise trip).
--
-- START WITH a value well below Number.MAX_SAFE_INTEGER (~9.0e15) so
-- Number(nextval)/String(nextval) stays exact in JS.
CREATE SEQUENCE IF NOT EXISTS ninepay_invoice_seq
  START WITH 3000000000000000
  INCREMENT BY 1;
