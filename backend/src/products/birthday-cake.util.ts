import { PrismaService } from '../prisma/prisma.service';

/**
 * Returns the subset of [productIds] that are "birthday cakes" — i.e. whose
 * Category is flagged `isBirthdayCakeCategory` (at most one such category). One
 * query, so it can safely decorate product lists with the `isBirthdayCake` flag
 * that switches on the customer cake-personalization wizard (quick-add "+",
 * detail, and cart). Replaces the old Collection-slug mechanism.
 */
export async function birthdayCakeProductIds(
  prisma: PrismaService,
  productIds: string[],
): Promise<Set<string>> {
  if (productIds.length === 0) return new Set();
  const hits = await prisma.product.findMany({
    where: {
      id: { in: productIds },
      category: { isBirthdayCakeCategory: true },
    },
    select: { id: true },
  });
  return new Set(hits.map((h) => h.id));
}
