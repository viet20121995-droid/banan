-- Reorder point per MES product (base UoM). 0 = no minimum watched.
ALTER TABLE "MfgProduct" ADD COLUMN "reorderPoint" DECIMAL(14,3) NOT NULL DEFAULT 0;
