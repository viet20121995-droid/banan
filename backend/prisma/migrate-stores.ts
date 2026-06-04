import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  const stores = await prisma.store.findMany({
    where: { slug: { in: ['banan-saigon', 'banan-le-thanh-ton'] } },
    include: { _count: { select: { products: true, orders: true } } },
  });
  console.log('Found stores:', stores.map((s) => ({
    slug: s.slug,
    name: s.name,
    products: s._count.products,
    orders: s._count.orders,
  })));

  const saigon = stores.find((s) => s.slug === 'banan-saigon');
  const lethanhton = stores.find((s) => s.slug === 'banan-le-thanh-ton');
  if (saigon && lethanhton) {
    // The re-seed created duplicate products in BOTH stores. We treat
    // lethanhton's copies as canonical. Wipe everything still pointing at
    // saigon (products, variants by cascade, collections, threads, orders),
    // then delete the saigon row.
    // Reassign any tracked users (merchant accounts) over to lethanhton.
    await prisma.user.updateMany({
      where: { storeId: saigon.id },
      data: { storeId: lethanhton.id },
    });
    // Reassign orders to lethanhton so order history isn't lost.
    await prisma.order.updateMany({
      where: { storeId: saigon.id },
      data: { storeId: lethanhton.id },
    });
    // Collections + threads owned by saigon become lethanhton's too.
    await prisma.collection.updateMany({
      where: { storeId: saigon.id },
      data: { storeId: lethanhton.id },
    });
    await prisma.thread.updateMany({
      where: { storeId: saigon.id },
      data: { storeId: lethanhton.id },
    });
    // Drop saigon's duplicate products (lethanhton already has canonical
    // copies). Variants + collection_items cascade per the schema.
    const productIds = (
      await prisma.product.findMany({
        where: { storeId: saigon.id },
        select: { id: true },
      })
    ).map((p) => p.id);
    if (productIds.length > 0) {
      // Detach any cart items / order items referencing saigon's products
      // by repointing them at the lethanhton equivalent (matched by slug).
      const lethanhtonProducts = await prisma.product.findMany({
        where: { storeId: lethanhton.id },
        select: { id: true, slug: true },
      });
      const slugToId = new Map(lethanhtonProducts.map((p) => [p.slug, p.id]));
      const saigonProducts = await prisma.product.findMany({
        where: { storeId: saigon.id },
        select: { id: true, slug: true },
      });
      for (const sp of saigonProducts) {
        const replacement = slugToId.get(sp.slug);
        if (replacement) {
          await prisma.orderItem.updateMany({
            where: { productId: sp.id },
            data: { productId: replacement },
          });
          await prisma.collectionItem.updateMany({
            where: { productId: sp.id },
            data: { productId: replacement },
          });
        }
      }
      // Now safe to delete saigon's products (and their variants by cascade).
      await prisma.product.deleteMany({
        where: { storeId: saigon.id },
      });
    }
    await prisma.store.delete({ where: { id: saigon.id } });
    console.log(
      'Cleaned up duplicate banan-saigon store + ' +
        productIds.length +
        ' duplicate products.',
    );
  } else if (saigon && !lethanhton) {
    // No new branch row — just rename in place.
    await prisma.store.update({
      where: { id: saigon.id },
      data: {
        slug: 'banan-le-thanh-ton',
        name: 'Banan – Lê Thánh Tôn',
      },
    });
    console.log('Renamed banan-saigon → banan-le-thanh-ton.');
  } else {
    console.log('Nothing to do.');
  }
}

main()
  .then(() => prisma.$disconnect())
  .catch((e) => {
    console.error(e);
    return prisma.$disconnect().then(() => process.exit(1));
  });
