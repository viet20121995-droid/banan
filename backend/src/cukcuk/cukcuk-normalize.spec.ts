import { createHmac } from 'node:crypto';

import { cukcukSignature, normalizePhone, normalizeRecord } from './cukcuk-normalize';

describe('cukcuk-normalize', () => {
  it('signs the login payload with HMAC-SHA256 over the exact JSON', () => {
    const payload = {
      AppID: 'CUKCUKOpenPlatform',
      Domain: 'vuonchuoi',
      LoginTime: '2026-09-15T00:00:00Z',
    };
    const expected = createHmac('sha256', 'secret').update(JSON.stringify(payload)).digest('hex');
    expect(cukcukSignature('secret', payload)).toBe(expected);
    expect(cukcukSignature('secret', payload)).toHaveLength(64);
  });

  it('normalises identity fields per dataset', () => {
    expect(
      normalizeRecord('invoices', {
        RefId: 'r1',
        RefNo: 'HD001',
        BranchId: 'b1',
        RefDate: '2026-09-01T10:00:00',
      }),
    ).toEqual({
      externalId: 'r1',
      label: 'HD001',
      branchId: 'b1',
      modifiedAt: new Date('2026-09-01T10:00:00'),
    });
    expect(normalizeRecord('branches', { Id: 'b1', Name: 'Lê Thánh Tôn' })).toMatchObject({
      externalId: 'b1',
      label: 'Lê Thánh Tôn',
      branchId: 'b1',
    });
    expect(
      normalizeRecord('customers', { Id: 'c1', Code: 'KH1', ModifiedDate: 'nope' }),
    ).toMatchObject({
      label: 'KH1',
      modifiedAt: null,
    });
    expect(() => normalizeRecord('items', { Name: 'x' })).toThrow();
  });

  it('normalises Vietnamese phone numbers', () => {
    expect(normalizePhone('+84 867 540 939')).toBe('0867540939');
    expect(normalizePhone('84867540939')).toBe('0867540939');
    expect(normalizePhone('0867-540-939')).toBe('0867540939');
    expect(normalizePhone('12')).toBeNull();
    expect(normalizePhone(null)).toBeNull();
  });
});
