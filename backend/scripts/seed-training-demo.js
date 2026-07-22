require('reflect-metadata');

const { NestFactory } = require('@nestjs/core');

const root = process.cwd();
const { AppModule } = require(`${root}/dist/src/app.module`);
const { ManufacturingService } = require(
  `${root}/dist/src/manufacturing/manufacturing.service`,
);
const { PrismaService } = require(`${root}/dist/src/prisma/prisma.service`);

async function main() {
  const app = await NestFactory.createApplicationContext(AppModule, {
    logger: false,
  });
  try {
    const mfg = app.get(ManufacturingService);
    const db = app.get(PrismaService);
    const categories = await db.mfgCategory.findMany();
    const rawCategory =
      categories.find((row) => row.nameVi.toLowerCase().includes('nguyen lieu')) ??
      categories.find((row) => row.nameEn.toLowerCase().includes('raw')) ??
      categories[0];
    const finishedCategory =
      categories.find((row) => row.nameVi.toLowerCase().includes('thanh pham')) ??
      categories.find((row) => row.nameEn.toLowerCase().includes('finished')) ??
      categories[0];
    const gram = await db.mfgUom.findUniqueOrThrow({ where: { code: 'g' } });
    const piece = await db.mfgUom.findUniqueOrThrow({ where: { code: 'pc' } });
    const centers = await db.mfgWorkCenter.findMany({
      where: { active: true },
      orderBy: { code: 'asc' },
      take: 3,
    });
    if (!rawCategory || !finishedCategory || centers.length === 0) {
      throw new Error('Missing manufacturing category or work-center seed data.');
    }

    let raw = await db.mfgProduct.findUnique({ where: { code: 'DEMO-QC-NVL' } });
    if (!raw) {
      raw = await mfg.createProduct({
        code: 'DEMO-QC-NVL',
        nameVi: '[DEMO] Hỗn hợp đào tạo QC',
        nameEn: '[DEMO] QC training mix',
        categoryId: rawCategory.id,
        uomId: gram.id,
        type: 'RAW',
        tracking: 'NONE',
        standardCost: 100,
      });
    }

    let output = await db.mfgProduct.findUnique({ where: { code: 'DEMO-QC-CAKE' } });
    if (!output) {
      output = await mfg.createProduct({
        code: 'DEMO-QC-CAKE',
        nameVi: '[DEMO] Bánh thực hành QC',
        nameEn: '[DEMO] QC training cake',
        categoryId: finishedCategory.id,
        uomId: piece.id,
        type: 'FINISHED',
        tracking: 'LOT',
        useExpiration: true,
        expirationDays: 3,
      });
    }

    let bom = await db.mfgBom.findFirst({
      where: { productId: output.id, active: true },
      orderBy: { version: 'desc' },
    });
    if (!bom) {
      bom = await mfg.createBom({
        productId: output.id,
        outputQty: 1,
        uomId: piece.id,
        lines: [{ componentId: raw.id, qty: 100, uomId: gram.id }],
        operations: [
          {
            nameVi: 'Cân và trộn',
            nameEn: 'Weigh and mix',
            workCenterId: centers[0].id,
            durationMinutes: 10,
            qualityPoints: [
              {
                titleVi: 'Nhiệt độ hỗn hợp',
                titleEn: 'Mix temperature',
                testType: 'MEASURE',
                normMin: 20,
                normMax: 25,
                unit: '°C',
              },
            ],
          },
          {
            nameVi: 'Nướng bánh',
            nameEn: 'Bake',
            workCenterId: (centers[1] ?? centers[0]).id,
            durationMinutes: 30,
            qualityPoints: [
              {
                titleVi: 'Nhiệt độ tâm bánh',
                titleEn: 'Core temperature',
                testType: 'MEASURE',
                normMin: 90,
                normMax: 96,
                unit: '°C',
              },
            ],
          },
          {
            nameVi: 'Hoàn thiện và đóng gói',
            nameEn: 'Finish and pack',
            workCenterId: (centers[2] ?? centers[0]).id,
            durationMinutes: 15,
            qualityPoints: [
              {
                titleVi: 'Ngoại quan đạt chuẩn',
                titleEn: 'Appearance accepted',
                testType: 'PASS_FAIL',
              },
            ],
          },
        ],
      });
    }

    const stock = await db.mfgLocation.findUniqueOrThrow({ where: { code: 'STOCK' } });
    const stockTotal = await db.mfgStockQuant.aggregate({
      where: { productId: raw.id, locationId: stock.id },
      _sum: { quantity: true },
    });
    const onHand = Number(stockTotal._sum.quantity ?? 0);
    if (onHand < 1000) {
      await mfg.receive({
        productId: raw.id,
        qty: 1000 - onHand,
        uomId: gram.id,
        unitCost: 100,
      });
    }

    async function ensureOrder(qtyToProduce) {
      let order = await db.mfgOrder.findFirst({
        where: {
          productId: output.id,
          qtyToProduce,
        },
        orderBy: { createdAt: 'desc' },
      });
      if (!order) {
        order = await mfg.createMO({ bomId: bom.id, qtyToProduce });
        await mfg.confirmMO(order.id);
        await mfg.reserve(order.id);
      }
      return db.mfgOrder.findUniqueOrThrow({
        where: { id: order.id },
        include: {
          components: true,
          workOrders: { orderBy: { sequence: 'asc' } },
        },
      });
    }

    const ready = await ensureOrder(1);
    const shortage = await ensureOrder(20);
    process.stdout.write(
      `${JSON.stringify({
        productId: output.id,
        bomId: bom.id,
        ready: { id: ready.id, code: ready.code },
        shortage: { id: shortage.id, code: shortage.code },
      })}\n`,
    );
  } finally {
    await app.close();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
