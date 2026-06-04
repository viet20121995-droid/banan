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

  // Shared hours across all branches: Mon-Thu 10am-9:30pm, Fri-Sun 10am-10pm.
  const branchHours = {
    mon: [['10:00', '21:30']],
    tue: [['10:00', '21:30']],
    wed: [['10:00', '21:30']],
    thu: [['10:00', '21:30']],
    fri: [['10:00', '22:00']],
    sat: [['10:00', '22:00']],
    sun: [['10:00', '22:00']],
  };

  // Migrate the original single-branch "banan-saigon" row (if it exists)
  // to be the new Lê Thánh Tôn branch. Keeps existing products attached so
  // the customer menu doesn't suddenly empty out after this seed runs.
  const legacy = await prisma.store.findUnique({
    where: { slug: 'banan-saigon' },
  });
  if (legacy) {
    await prisma.store.update({
      where: { slug: 'banan-saigon' },
      data: {
        slug: 'banan-le-thanh-ton',
        name: 'Banan – Lê Thánh Tôn',
        address: '15B8 Lê Thánh Tôn, Bến Nghé Ward, HCMC',
        phone: '+84867540939',
        openingHours: branchHours,
      },
    });
  }

  // Branch 1 is the "catalog owner" — products and delivery orders default
  // to this store. Pickup orders can be routed to any of the 4 branches.
  // Coordinates are approximate but accurate enough for the 3km delivery
  // radius check (each ward centroid is also approximate).
  const store = await prisma.store.upsert({
    where: { slug: 'banan-le-thanh-ton' },
    create: {
      name: 'Banan – Lê Thánh Tôn',
      slug: 'banan-le-thanh-ton',
      address: '15B8 Lê Thánh Tôn, Bến Nghé Ward, HCMC',
      phone: '+84867540939',
      lat: 10.7780,
      lng: 106.7030,
      wardCode: 'sai-gon',
      defaultKitchenId: kitchen.id,
      openingHours: branchHours,
    },
    update: {
      name: 'Banan – Lê Thánh Tôn',
      address: '15B8 Lê Thánh Tôn, Bến Nghé Ward, HCMC',
      phone: '+84867540939',
      lat: 10.7780,
      lng: 106.7030,
      wardCode: 'sai-gon',
      openingHours: branchHours,
    },
  });

  const branch2 = await prisma.store.upsert({
    where: { slug: 'banan-su-van-hanh' },
    create: {
      name: 'Banan – Sư Vạn Hạnh',
      slug: 'banan-su-van-hanh',
      address: '425A Sư Vạn Hạnh, Hòa Hưng Ward, HCMC',
      phone: '+84387835035',
      lat: 10.7793,
      lng: 106.6678,
      wardCode: 'hoa-hung',
      defaultKitchenId: kitchen.id,
      openingHours: branchHours,
    },
    update: {
      address: '425A Sư Vạn Hạnh, Hòa Hưng Ward, HCMC',
      phone: '+84387835035',
      lat: 10.7793,
      lng: 106.6678,
      wardCode: 'hoa-hung',
      openingHours: branchHours,
    },
  });

  const branch3 = await prisma.store.upsert({
    where: { slug: 'banan-ngo-quang-huy' },
    create: {
      name: 'Banan – Ngô Quang Huy',
      slug: 'banan-ngo-quang-huy',
      address: '34 Ngô Quang Huy, An Khánh Ward, HCMC',
      phone: '+84868897131',
      lat: 10.7800,
      lng: 106.7330,
      wardCode: 'an-khanh',
      defaultKitchenId: kitchen.id,
      openingHours: branchHours,
    },
    update: {
      address: '34 Ngô Quang Huy, An Khánh Ward, HCMC',
      phone: '+84868897131',
      lat: 10.7800,
      lng: 106.7330,
      wardCode: 'an-khanh',
      openingHours: branchHours,
    },
  });

  const branch4 = await prisma.store.upsert({
    where: { slug: 'banan-truong-sa' },
    create: {
      name: 'Banan – Trường Sa',
      slug: 'banan-truong-sa',
      address: '360 Trường Sa, Cầu Kiệu Ward, HCMC',
      phone: '+84379555934',
      lat: 10.7900,
      lng: 106.6840,
      wardCode: 'cau-kieu',
      defaultKitchenId: kitchen.id,
      openingHours: branchHours,
    },
    update: {
      address: '360 Trường Sa, Cầu Kiệu Ward, HCMC',
      phone: '+84379555934',
      lat: 10.7900,
      lng: 106.6840,
      wardCode: 'cau-kieu',
      openingHours: branchHours,
    },
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

  // Merchant accounts — one per branch so each store sees its own pickup queue.
  await prisma.user.upsert({
    where: { email: 'merchant@banan.local' },
    create: {
      email: 'merchant@banan.local',
      passwordHash,
      fullName: 'Lê Thánh Tôn Manager',
      role: 'MERCHANT_OWNER',
      storeId: store.id,
    },
    update: { storeId: store.id, fullName: 'Lê Thánh Tôn Manager' },
  });

  for (const branch of [
    { email: 'merchant-suvanhanh@banan.local', store: branch2, name: 'Sư Vạn Hạnh Manager' },
    { email: 'merchant-ngoquanghuy@banan.local', store: branch3, name: 'Ngô Quang Huy Manager' },
    { email: 'merchant-truongsa@banan.local', store: branch4, name: 'Trường Sa Manager' },
  ]) {
    await prisma.user.upsert({
      where: { email: branch.email },
      create: {
        email: branch.email,
        passwordHash,
        fullName: branch.name,
        role: 'MERCHANT_OWNER',
        storeId: branch.store.id,
      },
      update: { storeId: branch.store.id, fullName: branch.name },
    });
  }

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
