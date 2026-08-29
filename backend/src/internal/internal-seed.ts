/**
 * Internal-ops seed: default QC template (verbatim from the paper form) and
 * the 100-point Mystery Shopper template.
 *
 * Idempotent: a template row already present for (name, version) is left
 * COMPLETELY untouched — re-running never duplicates sections/items and
 * never overwrites production adjustments. A new wording is a NEW version.
 *
 * Lives in src/ (not prisma/) so `nest build` compiles it into dist and the
 * production image — which ships no TypeScript sources — can run it:
 *
 *   dev:  pnpm tsx src/internal/internal-seed.ts   (also runs via prisma/seed.ts)
 *   prod: node dist/src/internal/internal-seed.js
 */
import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcrypt';

import {
  MS_TEMPLATE_NAME,
  MS_TEMPLATE_SECTIONS,
  MS_TEMPLATE_VERSION,
  MS_TOTAL_WEIGHT,
} from './ms/ms-template-data';
import { QC_TEMPLATE_NAME, QC_TEMPLATE_SECTIONS, QC_TEMPLATE_VERSION } from './qc/qc-template-data';

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

  await seedTraineeAccount(prisma);
}

/**
 * Idempotent TRAINEE account: trainee@banan.local, linked to its own
 * InternalPerson so "my training" resolves. Re-runs never duplicate and
 * never reset a changed password (upsert update leaves credentials alone).
 * Password policy for further trainees: admins create them individually.
 */
export async function seedTraineeAccount(prisma: PrismaClient): Promise<void> {
  const existing = await prisma.user.findUnique({ where: { email: 'trainee@banan.local' } });
  if (existing && existing.role !== 'TRAINEE') {
    // Someone else owns this email — linking training data to it would hand
    // a foreign account the trainee surface. Fail LOUDLY, touch nothing.
    throw new Error(
      `trainee@banan.local already exists with role ${existing.role} — refusing to convert or ` +
        'link it. Rename/remove that account, then re-run the seed.',
    );
  }
  if (existing && !existing.isActive) {
    // Deliberate normalisation: the canonical trainee account is required to
    // be active. Password stays whatever it was changed to.
    await prisma.user.update({ where: { id: existing.id }, data: { isActive: true } });
    // eslint-disable-next-line no-console
    console.log('Re-activated trainee@banan.local');
  }
  const user =
    existing ??
    (await prisma.user.create({
      data: {
        email: 'trainee@banan.local',
        passwordHash: await bcrypt.hash('Vietnam123', 10),
        fullName: 'Trainee',
        role: 'TRAINEE',
        isActive: true,
      },
    }));
  if (!existing) {
    // eslint-disable-next-line no-console
    console.log('Seeded TRAINEE account trainee@banan.local');
  }

  const person = await prisma.internalPerson.findUnique({ where: { userId: user.id } });
  if (!person) {
    const store = await prisma.store.findFirst({ orderBy: { createdAt: 'asc' } });
    if (!store) {
      // eslint-disable-next-line no-console
      console.warn('No store yet — trainee InternalPerson skipped (re-run after store seed)');
      return;
    }
    await prisma.internalPerson.create({
      data: {
        fullName: 'Trainee',
        storeId: store.id,
        position: 'Trainee',
        userId: user.id,
        createdById: 'seed',
      },
    });
    // eslint-disable-next-line no-console
    console.log('Linked trainee@banan.local to a new InternalPerson');
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
