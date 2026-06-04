/**
 * Diagnostic scan: find any text column across the main content tables that
 * still carries a U+FFFD replacement char (the fingerprint of a UTF-8 string
 * mangled by a non-UTF-8 Windows console at insert time).
 *
 * Run:  cd backend && corepack pnpm tsx scripts/scan-encoding.ts
 */
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();
const BAD = '�';

function hit(label: string, id: string, field: string, value: string | null) {
  if (value && value.includes(BAD)) {
    console.log(`  [${label}] ${id}  ${field}=${JSON.stringify(value)}`);
    return 1;
  }
  return 0;
}

async function main() {
  let n = 0;

  for (const b of await prisma.banner.findMany())
    n += hit('Banner', b.id, 'title', b.title);

  for (const c of await prisma.collection.findMany())
    n += hit('Collection', c.id, 'name', c.name) +
         hit('Collection', c.id, 'description', (c as any).description ?? null);

  for (const c of await prisma.category.findMany())
    n += hit('Category', c.id, 'name', c.name);

  for (const p of await prisma.product.findMany())
    n += hit('Product', p.id, 'name', p.name) +
         hit('Product', p.id, 'description', p.description);

  // Threads / posts — table name may differ; guard so the scan still runs.
  try {
    // @ts-ignore - thread model is optional in some schemas
    for (const t of await prisma.thread.findMany())
      n += hit('Thread', t.id, 'title', (t as any).title ?? null) +
           hit('Thread', t.id, 'body', (t as any).body ?? null);
  } catch {
    // no thread model — skip
  }

  console.log(n === 0 ? 'Clean: no U+FFFD found.' : `Found ${n} corrupted field(s).`);
}

main()
  .catch((e) => { console.error(e); process.exitCode = 1; })
  .finally(() => prisma.$disconnect());
