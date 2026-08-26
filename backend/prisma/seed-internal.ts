/**
 * Internal-ops seed: default QC template (verbatim from the paper form) and
 * the 100-point Mystery Shopper template.
 *
 * Idempotent: a template row already present for (name, version) is left
 * COMPLETELY untouched — re-running never duplicates sections/items and
 * never overwrites production adjustments. A new wording is a NEW version.
 *
 * Standalone run: corepack pnpm tsx prisma/seed-internal.ts
 */
import { PrismaClient } from '@prisma/client';

import {
  QC_TEMPLATE_NAME,
  QC_TEMPLATE_SECTIONS,
  QC_TEMPLATE_VERSION,
} from '../src/internal/qc/qc-template-data';
import {
  MS_TEMPLATE_NAME,
  MS_TEMPLATE_SECTIONS,
  MS_TEMPLATE_VERSION,
  MS_TOTAL_WEIGHT,
} from '../src/internal/ms/ms-template-data';

export async function seedInternal(prisma: PrismaClient): Promise<void> {
  // ── QC template ──
  const existingQc = await prisma.qcTemplate.findUnique({
    where: { name_version: { name: QC_TEMPLATE_NAME, version: QC_TEMPLATE_VERSION } },
  });
  if (!existingQc) {
    await prisma.qcTemplate.create({
      data: {
        name: QC_TEMPLATE_NAME,
        version: QC_TEMPLATE_VERSION,
        sections: {
          create: QC_TEMPLATE_SECTIONS.map((s, sIdx) => ({
            title: s.title,
            sortOrder: sIdx,
            isRisk: s.isRisk,
            items: {
              create: s.items.map((it, iIdx) => ({
                text: it.text,
                sortOrder: iIdx,
                sourceRef: it.sourceRef,
              })),
            },
          })),
        },
      },
    });
    // eslint-disable-next-line no-console
    console.log(
      `Seeded QC template v${QC_TEMPLATE_VERSION} (${QC_TEMPLATE_SECTIONS.length} sections)`,
    );
  }

  // ── MS template ──
  if (MS_TOTAL_WEIGHT !== 100) {
    throw new Error(`MS template weights must total 100, got ${MS_TOTAL_WEIGHT}`);
  }
  const existingMs = await prisma.msTemplate.findUnique({
    where: { name_version: { name: MS_TEMPLATE_NAME, version: MS_TEMPLATE_VERSION } },
  });
  if (!existingMs) {
    await prisma.msTemplate.create({
      data: {
        name: MS_TEMPLATE_NAME,
        version: MS_TEMPLATE_VERSION,
        sections: {
          create: MS_TEMPLATE_SECTIONS.map((s, sIdx) => ({
            code: s.code,
            title: s.title,
            kind: s.kind,
            weight: s.weight,
            sortOrder: sIdx,
            questions: {
              create: s.questions.map((q, qIdx) => ({
                text: q.text,
                sortOrder: qIdx,
                allowNa: q.allowNa ?? false,
              })),
            },
          })),
        },
      },
    });
    // eslint-disable-next-line no-console
    console.log(
      `Seeded MS template v${MS_TEMPLATE_VERSION} (${MS_TEMPLATE_SECTIONS.length} sections)`,
    );
  }
}

// Standalone entrypoint.
if (require.main === module) {
  const prisma = new PrismaClient();
  seedInternal(prisma)
    .catch((e) => {
      // eslint-disable-next-line no-console
      console.error(e);
      process.exit(1);
    })
    .finally(async () => {
      await prisma.$disconnect();
    });
}
