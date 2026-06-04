/**
 * Banan production catalog seed — the real Banan menu (11 collections).
 * Re-runnable: categories upsert by slug, products upsert by
 * [storeId, slug]. Prices in VND. Attaches everything to the catalog-owner
 * store (banan-le-thanh-ton). Also pins the Best-Seller / Chef collections
 * to the customer home page.
 *
 * Run:  cd backend && corepack pnpm tsx prisma/seed-catalog.ts
 */
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

type Variant = { size: string; flavor: string; priceDelta?: number };
type Item = {
  name: string;
  price: number; // base price (smallest/only size)
  desc?: string;
  prep?: number;
  variants?: Variant[];
  /// Macaron-set composer: customer picks this many flavours (repeats ok).
  flavorPickCount?: number;
  flavorOptions?: string[];
};
type Group = {
  cat: string; // category name
  slug: string; // category slug
  badge?: string; // tag applied to every product in the group
  pinned?: boolean; // surface as a pinned home collection
  collectionDesc?: string;
  items: Item[];
};

/// Shared list of macaron flavours — used both for the single's variants
/// and the set composer options so they stay in sync.
const MACARON_FLAVORS = [
  'Jasmine',
  'Lemon',
  'Earl Grey',
  'Bitter Chocolate',
  'Black Sesame',
  'Mango Passion',
  'Raspberry Chocolate',
  'Salted Caramel',
  'Mint Chocolate',
];

const CATALOG: Group[] = [
  {
    cat: 'Classic Cake',
    slug: 'classic-cake',
    items: [
      { name: 'Strawberry Cake', price: 103000 },
      { name: 'Japanese Cheesecake', price: 76000 },
      { name: 'Bear Madeleines', price: 54000 },
      { name: 'Banana Walnut Bread', price: 59000 },
      { name: 'Nama Chocolate Cake', price: 92000 },
    ],
  },
  {
    cat: 'Pudding Collection',
    slug: 'pudding-collection',
    badge: 'Best Seller',
    pinned: true,
    collectionDesc: 'Our silkiest puddings — a customer favourite.',
    items: [
      { name: 'Creme Flan', price: 55000 },
      { name: 'Chocolate Pudding', price: 65000 },
      { name: 'Matcha Pudding', price: 65000 },
      { name: 'Raspberry Milk Cheezu', price: 65000 },
    ],
  },
  {
    cat: 'Can Cake Collection',
    slug: 'can-cake-collection',
    items: [
      { name: 'Melon Can Cake', price: 115000 },
      { name: 'Strawberry Can Cake', price: 113000 },
      { name: 'Tira-Presso Can Cake', price: 113000 },
      { name: 'Matcha-Misu Can Cake', price: 113000 },
    ],
  },
  {
    // Slug kept as "misu-box" so product slugs / re-seeds stay stable;
    // only the display name changed to "Boxes".
    cat: 'Boxes',
    slug: 'misu-box',
    items: [
      { name: 'Tira-Presso Misu Box', price: 184000 },
      { name: 'Matcha-Misu Box', price: 194000 },
    ],
  },
  {
    cat: 'Ichigo Collection',
    slug: 'ichigo-collection',
    items: [
      { name: 'Ichigo Matcha', price: 170000 },
      { name: 'Ichigo White Chocolate', price: 120000 },
      { name: 'Ichigo Chocolate', price: 170000 },
    ],
  },
  {
    cat: 'Daifuku Collection',
    slug: 'daifuku-collection',
    items: [
      { name: 'Kinako Daifuku', price: 73000 },
      { name: 'Matcha Daifuku', price: 80000 },
      { name: 'Red Bean Daifuku', price: 75000 },
      { name: 'Ichigo Daifuku', price: 73000 },
    ],
  },
  {
    cat: 'Mochi Collection',
    slug: 'mochi-collection',
    badge: 'Best Seller',
    pinned: true,
    collectionDesc: 'Pillowy mochi creations — flying off the shelves.',
    items: [
      { name: 'Mochi Berry Princess', price: 119000 },
      { name: 'Mochi Basque Matcha', price: 134000 },
      { name: 'Mochi Basque Ube', price: 107000 },
      { name: 'Mochi Basque Original', price: 107000 },
    ],
  },
  {
    cat: 'Macaron Collection',
    slug: 'macaron-collection',
    items: [
      {
        name: 'Macaron (single)',
        price: 38000,
        desc: 'Pick your flavour — crisp shell, smooth ganache.',
        variants: MACARON_FLAVORS.map((flavor) => ({
          size: 'Single',
          flavor,
        })),
      },
      {
        name: 'Set of 5 Macarons',
        price: 185000,
        desc: 'Tự chọn 5 vị macaron — có thể chọn nhiều cái cùng vị.',
        flavorPickCount: 5,
        flavorOptions: MACARON_FLAVORS,
      },
      {
        name: 'Set of 10 Macarons',
        price: 370000,
        desc: 'Tự chọn 10 vị macaron — có thể chọn nhiều cái cùng vị.',
        flavorPickCount: 10,
        flavorOptions: MACARON_FLAVORS,
      },
    ],
  },
  {
    cat: 'Cookie Choux Collection',
    slug: 'cookie-choux-collection',
    badge: "Chef's Recommended",
    pinned: true,
    collectionDesc: "The pastry chef's pick — crackly choux, lush cream.",
    items: [
      { name: 'Matcha Cookie Choux', price: 70000 },
      { name: 'Caramel Cookie Choux', price: 70000 },
      { name: 'Original Cookie Choux', price: 60000 },
    ],
  },
  {
    cat: 'Basque Burnt Cheesecake',
    slug: 'basque-burnt-cheesecake',
    items: [
      { name: 'Basque Burnt Original', price: 92000 },
      { name: 'Basque Burnt Ube', price: 92000 },
      { name: 'Basque Burnt Matcha', price: 119000 },
    ],
  },
  {
    cat: 'Birthday Cakes Collection',
    slug: 'birthday-cakes',
    collectionDesc: 'Whole cakes for celebrations — order ahead.',
    items: [
      {
        name: 'Signature Strawberry Cake',
        price: 778000,
        prep: 1440,
        variants: [
          { size: '16cm', flavor: 'Strawberry', priceDelta: 0 },
          { size: '18cm', flavor: 'Strawberry', priceDelta: 151000 },
          { size: '22cm', flavor: 'Strawberry', priceDelta: 734000 },
        ],
      },
      {
        name: 'Chocolate Strawberry Cake',
        price: 778000,
        prep: 1440,
        variants: [
          { size: '16cm', flavor: 'Chocolate Strawberry', priceDelta: 0 },
          { size: '18cm', flavor: 'Chocolate Strawberry', priceDelta: 151000 },
          { size: '22cm', flavor: 'Chocolate Strawberry', priceDelta: 734000 },
        ],
      },
      {
        name: 'Matcha Strawberry Cake',
        price: 972000,
        prep: 1440,
        variants: [
          { size: '16cm', flavor: 'Matcha Strawberry', priceDelta: 0 },
          { size: '18cm', flavor: 'Matcha Strawberry', priceDelta: 108000 },
        ],
      },
      {
        name: 'Original Lemon Cheesecake',
        price: 659000,
        prep: 1440,
        variants: [
          { size: '16cm', flavor: 'Lemon Cheesecake', priceDelta: 0 },
          { size: '18cm', flavor: 'Lemon Cheesecake', priceDelta: 345000 },
          { size: '22cm', flavor: 'Lemon Cheesecake', priceDelta: 637000 },
        ],
      },
      {
        name: 'Japanese Raspberry Cheesecake',
        price: 961000,
        prep: 1440,
        variants: [
          { size: '18cm', flavor: 'Raspberry Cheesecake', priceDelta: 0 },
          { size: '22cm', flavor: 'Raspberry Cheesecake', priceDelta: 443000 },
        ],
      },
      {
        name: 'Mochi Berry Queen',
        price: 850000,
        prep: 1440,
        variants: [{ size: '16cm', flavor: 'Mochi Berry', priceDelta: 0 }],
      },
      {
        name: 'Melon Whole Cake',
        price: 750000,
        prep: 1440,
        desc: '700g · Ø11.5 × H4.5 cm.',
        variants: [{ size: '700g', flavor: 'Melon', priceDelta: 0 }],
      },
      {
        name: 'Basque Burnt Ube (Whole)',
        price: 734000,
        prep: 1440,
        desc: '800g whole cake.',
        variants: [{ size: '800g', flavor: 'Ube', priceDelta: 0 }],
      },
      {
        name: 'Basque Burnt Matcha (Whole)',
        price: 950000,
        prep: 1440,
        desc: '800g whole cake.',
        variants: [{ size: '800g', flavor: 'Matcha', priceDelta: 0 }],
      },
      {
        name: 'Basque Burnt Original (Whole)',
        price: 734000,
        prep: 1440,
        desc: '800g whole cake.',
        variants: [{ size: '800g', flavor: 'Original', priceDelta: 0 }],
      },
    ],
  },
];

function slugify(s: string): string {
  return s
    .toLowerCase()
    .normalize('NFD')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/(^-|-$)/g, '');
}

async function main() {
  const store = await prisma.store.findUnique({
    where: { slug: 'banan-le-thanh-ton' },
    select: { id: true, name: true },
  });
  if (!store) {
    throw new Error(
      'Catalog store "banan-le-thanh-ton" not found. Run prisma/seed.ts first.',
    );
  }

  let catSort = 1;
  let productCount = 0;
  for (const group of CATALOG) {
    const category = await prisma.category.upsert({
      where: { slug: group.slug },
      create: { name: group.cat, slug: group.slug, sortOrder: catSort },
      update: { name: group.cat, sortOrder: catSort },
    });
    catSort += 1;

    const pinnedProductIds: string[] = [];

    for (let i = 0; i < group.items.length; i += 1) {
      const item = group.items[i];
      const pslug = `${group.slug}-${slugify(item.name)}`;
      const variants =
        item.variants && item.variants.length > 0
          ? item.variants
          : [{ size: 'Default', flavor: item.name, priceDelta: 0 }];
      const tags = group.badge ? [group.badge] : [];
      const description =
        item.desc ?? `${item.name} — from our ${group.cat}.`;
      // Deterministic placeholder photo per product (stable across reseeds).
      // Replace with real brand photography via the merchant menu editor.
      const images = [
        `https://picsum.photos/seed/${pslug}/800/600`,
      ];

      const product = await prisma.product.upsert({
        where: { storeId_slug: { storeId: store.id, slug: pslug } },
        create: {
          storeId: store.id,
          categoryId: category.id,
          name: item.name,
          slug: pslug,
          description,
          basePrice: item.price,
          images,
          tags,
          preparationMinutes: item.prep ?? 45,
          isAvailable: true,
          flavorPickCount: item.flavorPickCount ?? null,
          flavorOptions: item.flavorOptions ?? [],
          variants: {
            create: variants.map((v) => ({
              size: v.size,
              flavor: v.flavor,
              priceDelta: v.priceDelta ?? 0,
            })),
          },
        },
        update: {
          categoryId: category.id,
          name: item.name,
          description,
          basePrice: item.price,
          images,
          tags,
          preparationMinutes: item.prep ?? 45,
          isAvailable: true,
          flavorPickCount: item.flavorPickCount ?? null,
          flavorOptions: item.flavorOptions ?? [],
        },
      });
      pinnedProductIds.push(product.id);
      productCount += 1;
    }

    // Every catalog group also gets a manageable Collection (the merchant
    // "Collections" screen). Only badge groups are pinned to the customer
    // home carousel; the rest are available but unpinned.
    const pinned = group.pinned === true;
    const desc = group.collectionDesc ?? `${group.cat}.`;
    const collection = await prisma.collection.upsert({
      where: {
        storeId_slug: { storeId: store.id, slug: `home-${group.slug}` },
      },
      create: {
        storeId: store.id,
        name: group.cat,
        slug: `home-${group.slug}`,
        description: desc,
        isPinnedToHome: pinned,
        isActive: true,
        sortOrder: catSort,
      },
      update: {
        name: group.cat,
        description: desc,
        isPinnedToHome: pinned,
        isActive: true,
      },
    });
    // Reset + re-link items so the collection always mirrors the group.
    await prisma.collectionItem.deleteMany({
      where: { collectionId: collection.id },
    });
    await prisma.collectionItem.createMany({
      data: pinnedProductIds.map((pid, idx) => ({
        collectionId: collection.id,
        productId: pid,
        sortOrder: idx,
      })),
      skipDuplicates: true,
    });
  }

  // Hide the three generic demo products from the original dev seed so the
  // customer menu shows exactly the real Banan catalog. (Soft-hide rather
  // than delete — keeps any historical order items intact.)
  const classic = await prisma.category.findUnique({
    where: { slug: 'classic-cake' },
    select: { id: true },
  });
  await prisma.product.updateMany({
    where: {
      storeId: store.id,
      slug: { in: ['rose-lychee-mousse', 'tarte-au-citron', 'mango-passion-summer'] },
    },
    data: {
      isAvailable: false,
      ...(classic ? { categoryId: classic.id } : {}),
    },
  });

  // Drop any category that ends up with zero products and isn't part of
  // the real catalog (e.g. the old demo Mousse / Tart / Seasonal groups).
  const catalogSlugs = CATALOG.map((g) => g.slug);
  const allCats = await prisma.category.findMany({
    select: { id: true, slug: true, _count: { select: { products: true } } },
  });
  for (const c of allCats) {
    if (c._count.products === 0 && !catalogSlugs.includes(c.slug)) {
      await prisma.category.delete({ where: { id: c.id } });
    }
  }

  // Bundles — fixed-price combos that pull together products from
  // multiple categories. Re-runnable: upsert by slug, items are reset
  // each run so editing the BUNDLES array always wins.
  const BUNDLES: Array<{
    slug: string;
    name: string;
    description: string;
    priceVnd: number;
    pinned?: boolean;
    items: Array<{ productSlug: string; quantity: number }>;
  }> = [
    {
      slug: 'combo-bua-sang',
      name: 'Combo bữa sáng',
      description:
        '1 cookie choux + 1 mochi cho buổi sáng đầy năng lượng. ' +
        'Tiết kiệm 15% so với mua lẻ.',
      priceVnd: 110000,
      pinned: true,
      items: [
        { productSlug: 'cookie-choux-collection-original-cookie-choux', quantity: 1 },
        { productSlug: 'mochi-collection-mochi-basque-original', quantity: 1 },
      ],
    },
    {
      slug: 'combo-tra-chieu',
      name: 'Combo trà chiều',
      description:
        '3 macaron đa vị + 2 cookie choux — set hoàn hảo cho cuộc hẹn ' +
        'cà phê chiều với bạn bè.',
      priceVnd: 180000,
      pinned: true,
      items: [
        { productSlug: 'macaron-collection-set-of-5-macarons', quantity: 1 },
        { productSlug: 'cookie-choux-collection-matcha-cookie-choux', quantity: 2 },
      ],
    },
  ];

  for (const [i, bundleDef] of BUNDLES.entries()) {
    const bundleProducts = await prisma.product.findMany({
      where: {
        storeId: store.id,
        slug: { in: bundleDef.items.map((b) => b.productSlug) },
      },
      select: { id: true, slug: true },
    });
    const bySlug = new Map(bundleProducts.map((p) => [p.slug, p.id]));
    const fullyResolved = bundleDef.items.every((it) =>
      bySlug.has(it.productSlug),
    );
    if (!fullyResolved) {
      // Skip when a referenced product hasn't been seeded yet (early
      // partial seeds, custom CATALOG edits). Don't error — the bundle
      // is decorative.
      continue;
    }
    const bundle = await prisma.bundle.upsert({
      where: {
        storeId_slug: { storeId: store.id, slug: bundleDef.slug },
      },
      create: {
        storeId: store.id,
        slug: bundleDef.slug,
        name: bundleDef.name,
        description: bundleDef.description,
        priceVnd: bundleDef.priceVnd,
        isActive: true,
        isPinnedToHome: bundleDef.pinned ?? false,
        sortOrder: i,
      },
      update: {
        name: bundleDef.name,
        description: bundleDef.description,
        priceVnd: bundleDef.priceVnd,
        isActive: true,
        isPinnedToHome: bundleDef.pinned ?? false,
        sortOrder: i,
      },
    });
    // Reset + reseed items so editing CATALOG always wins.
    await prisma.bundleItem.deleteMany({ where: { bundleId: bundle.id } });
    await prisma.bundleItem.createMany({
      data: bundleDef.items.map((it) => ({
        bundleId: bundle.id,
        productId: bySlug.get(it.productSlug)!,
        quantity: it.quantity,
      })),
    });
  }

  console.log(
    `Catalog seeded into "${store.name}": ` +
      `${CATALOG.length} categories, ${productCount} products, ` +
      `${BUNDLES.length} bundles.`,
  );
}

main()
  .catch((e) => {
    console.error(e);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
