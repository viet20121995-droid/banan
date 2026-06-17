-- Add PAYOS to the PaymentProvider enum (switching away from VNPay).
-- VNPAY value is intentionally kept: Postgres can't drop an enum value safely
-- and removing it would require recreating the type. No rows use VNPAY.
ALTER TYPE "PaymentProvider" ADD VALUE IF NOT EXISTS 'PAYOS';
