import { PrismaClient } from '@prisma/client';

/**
 * Demo master data for the Kitchen MES. Idempotent: every row is keyed by a
 * stable `code`/name and upserted, so re-running only fills gaps. Covers the
 * 10 work centers from the spec, the four stock locations the engine resolves
 * by code, base UoMs, and one multi-level recipe (sponge → strawberry cake)
 * with baker's percentages — enough to exercise the whole produce flow.
 *
 * Run: `npx ts-node prisma/seed-manufacturing.ts` (or import seedManufacturing).
 */
export async function seedManufacturing(prisma: PrismaClient) {
  // ── UoM ──
  const g = await upsertUom(prisma, {
    code: 'g',
    nameVi: 'Gram',
    nameEn: 'Gram',
    category: 'weight',
    factor: 1,
  });
  const kg = await upsertUom(prisma, {
    code: 'kg',
    nameVi: 'Kilogram',
    nameEn: 'Kilogram',
    category: 'weight',
    factor: 1000,
  });
  const pc = await upsertUom(prisma, {
    code: 'pc',
    nameVi: 'Cái',
    nameEn: 'Piece',
    category: 'unit',
    factor: 1,
  });

  // ── locations (the engine resolves STOCK/SUPPLIER/PRODUCTION/SCRAP by code) ──
  await upsertLocation(prisma, {
    code: 'SUPPLIER',
    nameVi: 'Nhà cung cấp',
    nameEn: 'Supplier',
    type: 'SUPPLIER',
  });
  await upsertLocation(prisma, {
    code: 'STOCK',
    nameVi: 'Kho bếp',
    nameEn: 'Kitchen stock',
    type: 'INTERNAL',
  });
  await upsertLocation(prisma, {
    code: 'PRODUCTION',
    nameVi: 'Khu sản xuất',
    nameEn: 'Production',
    type: 'PRODUCTION',
  });
  await upsertLocation(prisma, {
    code: 'SCRAP',
    nameVi: 'Phế phẩm',
    nameEn: 'Scrap',
    type: 'SCRAP',
  });

  // ── categories ──
  const rawCat = await upsertCategory(prisma, 'Nguyên liệu', 'Raw material', 'AVCO');
  const semiCat = await upsertCategory(prisma, 'Bán thành phẩm', 'Semi-finished', 'AVCO');
  const finCat = await upsertCategory(prisma, 'Thành phẩm', 'Finished good', 'STANDARD');

  // ── work centers (7 stages, 10 cells) ──
  const wcPrep = await upsertWc(prisma, {
    code: 'WC-PREP',
    nameVi: 'Chuẩn bị',
    nameEn: 'Prep',
    costPerHour: 60000,
  });
  const wcMixL = await upsertWc(prisma, {
    code: 'WC-MIX-L',
    nameVi: 'Trộn máy lớn (SINMAG 20L)',
    nameEn: 'Mix large',
    costPerHour: 120000,
  });
  await upsertWc(prisma, {
    code: 'WC-MIX-S',
    nameVi: 'Trộn máy nhỏ',
    nameEn: 'Mix small',
    costPerHour: 80000,
  });
  const wcBake1 = await upsertWc(prisma, {
    code: 'WC-BAKE-U1',
    nameVi: 'Lò Unox 1',
    nameEn: 'Oven Unox 1',
    costPerHour: 150000,
  });
  await upsertWc(prisma, {
    code: 'WC-BAKE-U2',
    nameVi: 'Lò Unox 2',
    nameEn: 'Oven Unox 2',
    costPerHour: 150000,
  });
  await upsertWc(prisma, {
    code: 'WC-BAKE-DECK',
    nameVi: 'Lò Deck Berjaya',
    nameEn: 'Deck oven',
    costPerHour: 180000,
  });
  await upsertWc(prisma, {
    code: 'WC-CHILL',
    nameVi: 'Làm lạnh (Blast Chill)',
    nameEn: 'Blast chill',
    costPerHour: 90000,
  });
  const wcPack1 = await upsertWc(prisma, {
    code: 'WC-CUT-PACK',
    nameVi: 'Cắt & Đóng gói',
    nameEn: 'Cut & pack',
    costPerHour: 70000,
  });
  await upsertWc(prisma, {
    code: 'WC-FREEZE',
    nameVi: 'Cấp đông (Blast Freeze)',
    nameEn: 'Blast freeze',
    costPerHour: 90000,
  });
  const wcDecor = await upsertWc(prisma, {
    code: 'WC-DECOR',
    nameVi: 'Trang trí / Đóng gói ②',
    nameEn: 'Decorate & pack',
    costPerHour: 80000,
  });

  // ── products ──
  const flour = await upsertProduct(prisma, {
    code: 'RAW-FLOUR',
    nameVi: 'Bột mì số 8',
    nameEn: 'Cake flour',
    categoryId: rawCat,
    uomId: g,
    type: 'RAW',
    tracking: 'LOT',
    useExpiration: true,
    expirationDays: 180,
  });
  const sugar = await upsertProduct(prisma, {
    code: 'RAW-SUGAR',
    nameVi: 'Đường',
    nameEn: 'Sugar',
    categoryId: rawCat,
    uomId: g,
    type: 'RAW',
    tracking: 'LOT',
    useExpiration: true,
    expirationDays: 365,
  });
  const egg = await upsertProduct(prisma, {
    code: 'RAW-EGG',
    nameVi: 'Trứng gà',
    nameEn: 'Egg',
    categoryId: rawCat,
    uomId: g,
    type: 'RAW',
    tracking: 'LOT',
    useExpiration: true,
    expirationDays: 21,
  });
  const cream = await upsertProduct(prisma, {
    code: 'RAW-CREAM',
    nameVi: 'Kem tươi',
    nameEn: 'Whipping cream',
    categoryId: rawCat,
    uomId: g,
    type: 'RAW',
    tracking: 'LOT',
    useExpiration: true,
    expirationDays: 30,
  });
  const berry = await upsertProduct(prisma, {
    code: 'RAW-STRAW',
    nameVi: 'Dâu tây',
    nameEn: 'Strawberry',
    categoryId: rawCat,
    uomId: g,
    type: 'RAW',
    tracking: 'LOT',
    useExpiration: true,
    expirationDays: 7,
  });

  const sponge = await upsertProduct(prisma, {
    code: 'SEMI-SPONGE',
    nameVi: 'Cốt bánh bông lan',
    nameEn: 'Sponge base',
    categoryId: semiCat,
    uomId: g,
    type: 'SEMI',
    tracking: 'LOT',
    useExpiration: true,
    expirationDays: 3,
  });
  const cake = await upsertProduct(prisma, {
    code: 'FIN-STRAWCAKE',
    nameVi: 'Bánh kem dâu',
    nameEn: 'Strawberry cream cake',
    categoryId: finCat,
    uomId: g,
    type: 'FINISHED',
    tracking: 'LOT',
    useExpiration: true,
    expirationDays: 2,
  });

  // ── BoM: sponge (1000g out) — flour 500 / sugar 350 / egg 400, flour = basis ──
  await upsertBom(prisma, {
    productId: sponge,
    outputQty: 1000,
    uomId: g,
    lines: [
      { componentId: flour, qty: 500, uomId: g, isBasis: true },
      { componentId: sugar, qty: 350, uomId: g },
      { componentId: egg, qty: 400, uomId: g },
    ],
    operations: [
      {
        sequence: 1,
        nameVi: 'Chuẩn bị',
        nameEn: 'Prep',
        workCenterId: wcPrep,
        durationMinutes: 15,
      },
      { sequence: 2, nameVi: 'Trộn bột', nameEn: 'Mix', workCenterId: wcMixL, durationMinutes: 20 },
      { sequence: 3, nameVi: 'Nướng', nameEn: 'Bake', workCenterId: wcBake1, durationMinutes: 35 },
    ],
  });

  // ── BoM: strawberry cake (1000g out) — sponge 600 / cream 300 / strawberry 100 ──
  await upsertBom(prisma, {
    productId: cake,
    outputQty: 1000,
    uomId: g,
    lines: [
      { componentId: sponge, qty: 600, uomId: g, isBasis: true },
      { componentId: cream, qty: 300, uomId: g },
      { componentId: berry, qty: 100, uomId: g },
    ],
    operations: [
      {
        sequence: 1,
        nameVi: 'Cắt lớp',
        nameEn: 'Slice',
        workCenterId: wcPack1,
        durationMinutes: 10,
      },
      {
        sequence: 2,
        nameVi: 'Trang trí',
        nameEn: 'Decorate',
        workCenterId: wcDecor,
        durationMinutes: 25,
      },
    ],
  });

  return { g, kg, pc, ids: { flour, sugar, egg, cream, berry, sponge, cake } };
}

// ── idempotent upsert helpers ──────────────────────────────────────────────

async function upsertUom(
  prisma: PrismaClient,
  u: { code: string; nameVi: string; nameEn: string; category: string; factor: number },
) {
  const row = await prisma.mfgUom.upsert({
    where: { code: u.code },
    update: {},
    create: u,
  });
  return row.id;
}

async function upsertLocation(
  prisma: PrismaClient,
  l: {
    code: string;
    nameVi: string;
    nameEn: string;
    type: 'SUPPLIER' | 'INTERNAL' | 'PRODUCTION' | 'SCRAP';
  },
) {
  const row = await prisma.mfgLocation.upsert({ where: { code: l.code }, update: {}, create: l });
  return row.id;
}

async function upsertCategory(
  prisma: PrismaClient,
  nameVi: string,
  nameEn: string,
  costMethod: 'AVCO' | 'STANDARD',
) {
  const found = await prisma.mfgCategory.findFirst({ where: { nameVi } });
  if (found) return found.id;
  const row = await prisma.mfgCategory.create({ data: { nameVi, nameEn, costMethod } });
  return row.id;
}

async function upsertWc(
  prisma: PrismaClient,
  w: { code: string; nameVi: string; nameEn: string; costPerHour: number },
) {
  const row = await prisma.mfgWorkCenter.upsert({ where: { code: w.code }, update: {}, create: w });
  return row.id;
}

async function upsertProduct(
  prisma: PrismaClient,
  p: {
    code: string;
    nameVi: string;
    nameEn: string;
    categoryId: string;
    uomId: string;
    type: 'RAW' | 'SEMI' | 'FINISHED' | 'PACKAGING';
    tracking: 'NONE' | 'LOT';
    useExpiration: boolean;
    expirationDays: number;
  },
) {
  const row = await prisma.mfgProduct.upsert({ where: { code: p.code }, update: {}, create: p });
  return row.id;
}

async function upsertBom(
  prisma: PrismaClient,
  b: {
    productId: string;
    outputQty: number;
    uomId: string;
    lines: { componentId: string; qty: number; uomId: string; isBasis?: boolean }[];
    operations: {
      sequence: number;
      nameVi: string;
      nameEn: string;
      workCenterId: string;
      durationMinutes: number;
    }[];
  },
) {
  const existing = await prisma.mfgBom.findFirst({
    where: { productId: b.productId, active: true },
  });
  if (existing) return existing.id;

  // Baker's % vs the flagged basis line's weight (already in grams here).
  const basis =
    b.lines.filter((l) => l.isBasis).reduce((s, l) => s + l.qty, 0) ||
    b.lines.reduce((s, l) => s + l.qty, 0);

  const bom = await prisma.mfgBom.create({
    data: {
      productId: b.productId,
      outputQty: b.outputQty,
      uomId: b.uomId,
      lines: {
        create: b.lines.map((l) => ({
          componentId: l.componentId,
          qty: l.qty,
          uomId: l.uomId,
          ratioPercent: basis > 0 ? Math.round((l.qty / basis) * 10000) / 100 : 0,
        })),
      },
      operations: { create: b.operations },
    },
  });
  return bom.id;
}

// Allow `npx ts-node prisma/seed-manufacturing.ts` directly.
if (require.main === module) {
  const prisma = new PrismaClient();
  seedManufacturing(prisma)
    .then((r) => {
      // eslint-disable-next-line no-console
      console.log('Seeded manufacturing demo data:', r.ids);
    })
    .catch((e) => {
      // eslint-disable-next-line no-console
      console.error(e);
      process.exit(1);
    })
    .finally(() => prisma.$disconnect());
}
