/**
 * One-off repair: a Banner row was stored with a corrupted title —
 * "Khuyến mãi hè" had been mangled into "Khuy?n m�i h�" (a literal '?'
 * plus two U+FFFD replacement chars) because it was inserted through a
 * Windows console whose active codepage wasn't UTF-8.
 *
 * This script reads the correct text from a UTF-8 source literal (this
 * file) and writes it straight to Postgres via Prisma — no shell argument
 * boundary, so the diacritics survive intact.
 *
 * Run:  cd backend && corepack pnpm tsx scripts/fix-banner-encoding.ts
 */
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

/// Heuristic: a title is corrupted if it carries a U+FFFD replacement char
/// or the tell-tale "Khuy?n" fragment from the mangled promo banner.
function isCorrupted(title: string | null): boolean {
  if (!title) return false;
  return title.includes('�') || title.includes('Khuy?n');
}

async function main() {
  const banners = await prisma.banner.findMany({
    select: { id: true, title: true },
  });
  console.log(`Found ${banners.length} banner(s):`);
  for (const b of banners) {
    console.log(`  ${b.id}  title=${JSON.stringify(b.title)}  corrupted=${isCorrupted(b.title)}`);
  }

  const broken = banners.filter((b) => isCorrupted(b.title));
  if (broken.length === 0) {
    console.log('Nothing to repair.');
    return;
  }

  const corrected = 'Khuyến mãi hè';
  for (const b of broken) {
    await prisma.banner.update({
      where: { id: b.id },
      data: { title: corrected },
    });
    console.log(`Repaired ${b.id} -> ${JSON.stringify(corrected)}`);
  }
}

main()
  .catch((e) => {
    console.error(e);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
