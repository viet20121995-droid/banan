import { ConflictException } from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { normalizeSku, rethrowSkuConflict, skuUpdateValue } from './products.service';

/**
 * SKU semantics on variant sync. The bug being pinned: an old client that
 * doesn't send the `sku` key at all must NOT wipe the stored SKU — only an
 * explicit null/empty may clear it.
 */
describe('variant SKU update semantics', () => {
  it('omitted field (undefined) keeps the stored SKU: Prisma skips the column', () => {
    expect(skuUpdateValue(undefined)).toBeUndefined();
  });

  it('explicit null clears the SKU', () => {
    expect(skuUpdateValue(null)).toBeNull();
  });

  it('empty and whitespace-only strings clear the SKU', () => {
    expect(skuUpdateValue('')).toBeNull();
    expect(skuUpdateValue('   ')).toBeNull();
  });

  it('a real value is trimmed and uppercased', () => {
    expect(skuUpdateValue('  vt00708 ')).toBe('VT00708');
    expect(normalizeSku('fz-hc-028-s')).toBe('FZ-HC-028-S');
  });

  it('new variants without an SKU are created with null', () => {
    expect(normalizeSku(null)).toBeNull();
  });
});

describe('duplicate SKU -> 409 SKU_TAKEN', () => {
  const p2002 = (target: string[]) =>
    new Prisma.PrismaClientKnownRequestError('Unique constraint failed', {
      code: 'P2002',
      clientVersion: 'test',
      meta: { target },
    });

  it('maps the sku unique-index violation to ConflictException', () => {
    expect(() => rethrowSkuConflict(p2002(['sku']))).toThrow(ConflictException);
    try {
      rethrowSkuConflict(p2002(['sku']));
    } catch (e) {
      expect((e as ConflictException).getResponse()).toMatchObject({
        code: 'SKU_TAKEN',
      });
    }
  });

  it('rethrows every other error untouched', () => {
    const other = p2002(['slug']);
    expect(() => rethrowSkuConflict(other)).toThrow(other);
    const plain = new Error('boom');
    expect(() => rethrowSkuConflict(plain)).toThrow(plain);
  });
});
