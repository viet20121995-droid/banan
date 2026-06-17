import { BadRequestException } from '@nestjs/common';

import { merchantStoreScope } from './merchant-scope';

/**
 * The recurring "null = admin/chain-wide" footgun lives here now. This spec
 * locks the three outcomes so bundles/collections/threads/reviews/reports all
 * inherit a correct scope and a misconfigured merchant can't read chain-wide.
 */

const user = (over: Record<string, unknown> = {}) =>
  ({ sub: 'u1', role: 'MERCHANT_OWNER', storeId: 's1', ...over }) as never;

describe('merchantStoreScope', () => {
  it('ADMIN → null (chain-wide)', () => {
    expect(merchantStoreScope(user({ role: 'ADMIN', storeId: null }))).toBeNull();
  });

  it('merchant owner with a store → that storeId', () => {
    expect(merchantStoreScope(user({ role: 'MERCHANT_OWNER', storeId: 's9' }))).toBe('s9');
  });

  it('merchant staff with a store → that storeId', () => {
    expect(merchantStoreScope(user({ role: 'MERCHANT_STAFF', storeId: 's9' }))).toBe('s9');
  });

  it('merchant OWNER without a store → NO_STORE_ASSIGNED (no chain-wide fallthrough)', () => {
    try {
      merchantStoreScope(user({ role: 'MERCHANT_OWNER', storeId: null }));
      throw new Error('should have thrown');
    } catch (e) {
      expect(e).toBeInstanceOf(BadRequestException);
      expect((e as BadRequestException).getResponse()).toMatchObject({
        code: 'NO_STORE_ASSIGNED',
      });
    }
  });

  it('merchant STAFF without a store → NO_STORE_ASSIGNED', () => {
    expect(() =>
      merchantStoreScope(user({ role: 'MERCHANT_STAFF', storeId: undefined })),
    ).toThrow(BadRequestException);
  });
});
