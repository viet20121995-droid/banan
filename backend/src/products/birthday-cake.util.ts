import { PrismaService } from '../prisma/prisma.service';

/**
 * Returns the subset of [productIds] that belong to the chain's birthday-cake
 * collection (slug stored on the `DeliveryConfig` singleton — the same
 * definition that drives the delivery-fee tier). One query, so it can safely
 * decorate product lists with the `isBirthdayCake` flag that switches on the
 * customer cake-personalization wizard (quick-add "+", detail, and cart).
 */
export async function birthdayCakeProductIds(
  prisma: PrismaService,
  productIds: string[],
): Promise<Set<string>> {
  if (productIds.length === 0) return new Set();
  const config = await prisma.deliveryConfig.findUnique({
    where: { id: 'default' },
    select: { birthdayCakeCollectionSlug: true },
  });
  const slug = config?.birthdayCakeCollectionSlug;
  if (!slug) return new Set();
  const hits = await prisma.collectionItem.findMany({
    where: { productId: { in: productIds }, collection: { slug } },
    select: { productId: true },
  });
  return new Set(hits.map((h) => h.productId));
}
