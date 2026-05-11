/**
 * Banan dev seed. Creates 1 admin, 1 store + manager, 1 kitchen + manager,
 * a handful of categories and products. Re-runnable — uses upsert by unique
 * fields so reseeding doesn't blow up.
 */
import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcrypt';

const prisma = new PrismaClient();

async function main() {
  const passwordHash = await bcrypt.hash('banan123', 10);

  const kitchen = await prisma.kitchen.upsert({
    where: { id: 'kitchen-main' },
    create: {
      id: 'kitchen-main',
      name: 'Banan Central Kitchen',
      address: '15 Le Loi, District 1, HCMC',
      capacityPerHour: 60,
    },
    update: {},
  });

  const store = await prisma.store.upsert({
    where: { slug: 'banan-saigon' },
    create: {
      name: 'Banan Saigon',
      slug: 'banan-saigon',
      address: '88 Dong Khoi, District 1, HCMC',
      phone: '+84 28 1234 5678',
      defaultKitchenId: kitchen.id,
      openingHours: {
        mon: [['09:00', '21:00']],
        tue: [['09:00', '21:00']],
        wed: [['09:00', '21:00']],
        thu: [['09:00', '21:00']],
        fri: [['09:00', '22:00']],
        sat: [['09:00', '22:00']],
        sun: [['09:00', '21:00']],
      },
    },
    update: {},
  });

  const admin = await prisma.user.upsert({
    where: { email: 'admin@banan.local' },
    create: {
      email: 'admin@banan.local',
      passwordHash,
      fullName: 'Banan Admin',
      role: 'ADMIN',
    },
    update: {},
  });

  await prisma.user.upsert({
    where: { email: 'merchant@banan.local' },
    create: {
      email: 'merchant@banan.local',
      passwordHash,
      fullName: 'Saigon Manager',
      role: 'MERCHANT_OWNER',
      storeId: store.id,
    },
    update: { storeId: store.id },
  });

  await prisma.user.upsert({
    where: { email: 'kitchen@banan.local' },
    create: {
      email: 'kitchen@banan.local',
      passwordHash,
      fullName: 'Kitchen Manager',
      role: 'KITCHEN_MANAGER',
      kitchenId: kitchen.id,
    },
    update: { kitchenId: kitchen.id },
  });

  await prisma.user.upsert({
    where: { email: 'customer@banan.local' },
    create: {
      email: 'customer@banan.local',
      passwordHash,
      fullName: 'Demo Customer',
      role: 'CUSTOMER',
      membershipTier: 'GOLD',
      pointsBalance: 1500,
    },
    update: {},
  });

  const mousse = await prisma.category.upsert({
    where: { slug: 'mousse' },
    create: { name: 'Mousse', slug: 'mousse', sortOrder: 1 },
    update: {},
  });
  const tart = await prisma.category.upsert({
    where: { slug: 'tart' },
    create: { name: 'Tart', slug: 'tart', sortOrder: 2 },
    update: {},
  });
  const seasonal = await prisma.category.upsert({
    where: { slug: 'seasonal' },
    create: { name: 'Seasonal', slug: 'seasonal', sortOrder: 3 },
    update: {},
  });

  await prisma.product.upsert({
    where: { storeId_slug: { storeId: store.id, slug: 'rose-lychee-mousse' } },
    create: {
      storeId: store.id,
      categoryId: mousse.id,
      name: 'Rose Lychee Mousse',
      slug: 'rose-lychee-mousse',
      description:
        'Silky white-chocolate mousse layered with rose gel and lychee compote.',
      basePrice: 380000,
      images: [],
      preparationMinutes: 90,
      variants: {
        create: [
          { size: '6"', flavor: 'Rose Lychee', priceDelta: 0 },
          { size: '8"', flavor: 'Rose Lychee', priceDelta: 180000 },
        ],
      },
    },
    update: {},
  });

  await prisma.product.upsert({
    where: { storeId_slug: { storeId: store.id, slug: 'tarte-au-citron' } },
    create: {
      storeId: store.id,
      categoryId: tart.id,
      name: 'Tarte au Citron',
      slug: 'tarte-au-citron',
      description: 'Classic French lemon tart with torched Italian meringue.',
      basePrice: 240000,
      images: [],
      preparationMinutes: 45,
      variants: {
        create: [
          { size: 'Individual', flavor: 'Lemon', priceDelta: 0 },
          { size: 'Whole 8"', flavor: 'Lemon', priceDelta: 320000 },
        ],
      },
    },
    update: {},
  });

  await prisma.product.upsert({
    where: { storeId_slug: { storeId: store.id, slug: 'mango-passion-summer' } },
    create: {
      storeId: store.id,
      categoryId: seasonal.id,
      name: 'Mango Passion (Summer)',
      slug: 'mango-passion-summer',
      description: 'Limited summer creation: mango cremeux, passion gel, almond dacquoise.',
      basePrice: 420000,
      images: [],
      preparationMinutes: 75,
      isSeasonal: true,
      seasonStart: new Date('2026-04-01'),
      seasonEnd: new Date('2026-09-30'),
      variants: {
        create: [
          { size: '6"', flavor: 'Mango Passion', priceDelta: 0 },
          { size: '8"', flavor: 'Mango Passion', priceDelta: 200000 },
        ],
      },
    },
    update: {},
  });

  // Sample coupons (M7).
  const farFuture = new Date('2099-12-31');
  await prisma.coupon.upsert({
    where: { code: 'WELCOME10' },
    create: {
      code: 'WELCOME10',
      type: 'PERCENT',
      value: 10,
      startsAt: new Date('2024-01-01'),
      endsAt: farFuture,
      perUserLimit: 1,
    },
    update: {},
  });
  await prisma.coupon.upsert({
    where: { code: 'BANAN20K' },
    create: {
      code: 'BANAN20K',
      type: 'FIXED',
      value: 20000,
      minSubtotal: 100000,
      startsAt: new Date('2024-01-01'),
      endsAt: farFuture,
      perUserLimit: 5,
    },
    update: {},
  });
  await prisma.coupon.upsert({
    where: { code: 'FREEDELIV' },
    create: {
      code: 'FREEDELIV',
      type: 'FREE_DELIVERY',
      value: 0,
      startsAt: new Date('2024-01-01'),
      endsAt: farFuture,
      perUserLimit: 3,
    },
    update: {},
  });

  // eslint-disable-next-line no-console
  console.log('Seed complete. Login emails:');
  // eslint-disable-next-line no-console
  console.log('  admin@banan.local / banan123');
  // eslint-disable-next-line no-console
  console.log('  merchant@banan.local / banan123');
  // eslint-disable-next-line no-console
  console.log('  kitchen@banan.local / banan123');
  // eslint-disable-next-line no-console
  console.log('  customer@banan.local / banan123');
  // eslint-disable-next-line no-console
  console.log(`Admin id: ${admin.id}`);
}

main()
  .catch((e) => {
    // eslint-disable-next-line no-console
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
