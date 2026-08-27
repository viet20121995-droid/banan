-- Store the PDF rendered at complete/approve time so retries and downloads
-- serve the approved bytes even after evidence files are deleted.
ALTER TABLE "QcReportDelivery" ADD COLUMN "pdfFile" TEXT;
ALTER TABLE "MsReportDelivery" ADD COLUMN "pdfFile" TEXT;
