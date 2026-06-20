import { Prisma } from '@prisma/client';

/**
 * Coarse advisory lock that serialises every mutation which can change combo
 * (Bundle) membership or validity:
 *   - bundle create / update / remove
 *   - product update / remove / bulk-price (a product's price, flavour-pick,
 *     selling days or availability all feed a combo's validity; deleting one
 *     breaks every combo that contains it)
 *
 * Held to transaction end. It must be taken FIRST in any such transaction —
 * before any per-bundle `bundle:<id>` lock — so the global lock-acquisition
 * order stays consistent (coarse → per-bundle, ids sorted) and deadlock-free.
 *
 * Under this lock the "which combos contain product X" membership query is
 * stable (no concurrent bundle edit can add/remove the product mid-flight), so
 * product writes can reliably find and re-validate the combos they affect.
 *
 * Checkout deliberately does NOT take this lock — it would serialise every
 * combo order. Checkout instead takes per-bundle `bundle:<id>` locks keyed on
 * its own (known) bundle ids; bundle/product writes take the same per-bundle
 * lock when they deactivate a combo, so the two still serialise on that id.
 */
export async function lockCatalogBundles(tx: Prisma.TransactionClient): Promise<void> {
  await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtextextended(${'catalog:bundles'}, 0))`;
}

/** Per-combo advisory lock (same key checkout re-validation uses). Acquire the
 *  coarse lock first, and acquire multiple of these in sorted-id order. */
export async function lockBundle(tx: Prisma.TransactionClient, bundleId: string): Promise<void> {
  await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtextextended(${'bundle:' + bundleId}, 0))`;
}
