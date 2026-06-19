import { ProductsService } from './products.service';

/**
 * A combo (BundleItem) can pin a specific product variant. Because the DB FK is
 * ON DELETE SET NULL, deleting a pinned variant would silently null the pin and
 * the combo would re-resolve to a different variant at order time (wrong item,
 * wrong price, wrong discount). reconcileVariants must refuse such a delete.
 * The method only touches its `tx` arg, so we invoke it via the prototype with
 * a hand-mocked transaction client.
 */
describe('ProductsService.reconcileVariants (combo variant-pin protection)', () => {
  const call = (
    tx: unknown,
    productId: string,
    variants: unknown,
  ): Promise<void> =>
    (
      ProductsService.prototype as unknown as {
        reconcileVariants(t: unknown, p: string, v: unknown): Promise<void>;
      }
    ).reconcileVariants.call({}, tx, productId, variants);

  it('refuses to delete a variant pinned by a combo', async () => {
    const tx = {
      productVariant: {
        findMany: jest.fn().mockResolvedValue([{ id: 'v1' }, { id: 'v2' }]),
        deleteMany: jest.fn(),
        update: jest.fn(),
        create: jest.fn(),
      },
      bundleItem: {
        findMany: jest
          .fn()
          .mockResolvedValue([{ bundle: { name: 'Combo Tết' } }]),
      },
    };
    // Incoming keeps only v1 → v2 would be deleted, but v2 is pinned by a combo.
    await expect(
      call(tx, 'p1', [{ id: 'v1', size: 'S', flavor: 'A' }]),
    ).rejects.toMatchObject({ response: { code: 'VARIANT_PINNED_BY_BUNDLE' } });
    expect(tx.productVariant.deleteMany).not.toHaveBeenCalled();
  });

  it('deletes a removed variant that no combo pins', async () => {
    const tx = {
      productVariant: {
        findMany: jest.fn().mockResolvedValue([{ id: 'v1' }, { id: 'v2' }]),
        deleteMany: jest.fn().mockResolvedValue({ count: 1 }),
        update: jest.fn().mockResolvedValue({}),
        create: jest.fn().mockResolvedValue({}),
      },
      bundleItem: { findMany: jest.fn().mockResolvedValue([]) },
    };
    await call(tx, 'p1', [{ id: 'v1', size: 'S', flavor: 'A' }]);
    expect(tx.bundleItem.findMany).toHaveBeenCalledWith({
      where: { variantId: { in: ['v2'] } },
      select: { bundle: { select: { name: true } } },
    });
    expect(tx.productVariant.deleteMany).toHaveBeenCalledWith({
      where: { id: { in: ['v2'] } },
    });
    expect(tx.productVariant.update).toHaveBeenCalledTimes(1); // v1 kept/updated
  });
});
