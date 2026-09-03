-- AlterTable
ALTER TABLE "MfgProduct" ADD COLUMN "drinkIngredient" BOOLEAN NOT NULL DEFAULT false;

-- Flag the bar-restock catalogue from the Sept 2026 branch order sheet
-- ("NGUYÊN LIỆU PHA CHẾ / DRINK INGREDIENTS"). Unknown codes are simply skipped.
UPDATE "MfgProduct" SET "drinkIngredient" = true WHERE code IN (
  'FH-L-004-1',
  'FH-L-027-2',
  'FH-L-008-2',
  'FH-L-030-1',
  'FH-L-003-2',
  'FH-L-037-2',
  'PROD00274',
  'FS-L-165-3',
  'DS-HC-004-2-G',
  'FS-L-167-3',
  'DS-HC-005-2-G',
  'FH-L-043-2',
  'DS-HC-010-2-G',
  'DU0040',
  'FH-C-064-1-S',
  'FS-L-041-3',
  'FS-L-125-3',
  'FS-L-080-3',
  'FS-L-044-3',
  'FS-L-169-3',
  'FS-L-128-3',
  'DS-HC-006-2-G',
  'DS-HC-007-2-G',
  'DS-HC-008-2-G',
  'DS-HC-009-2-G',
  'FS-L-115-3',
  'FS-L-168-3',
  'FS-L-001-3',
  'FS-L-166-3',
  'PROD00466',
  'PROD00429',
  'FS-HC-018-3-G',
  'PROD00013',
  'FH-HC-004-1-S',
  'PROD00324',
  'FS-HC-030-3-G'
);
