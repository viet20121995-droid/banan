import { CashPaymentService } from './cash.service';

/**
 * COD gate: the storefront is online-prepaid only, so cash must be refused
 * unless COD_ENABLED=true — hiding the option in the customer app is not
 * enforcement (a direct API call would otherwise still book a COD order).
 */
describe('CashPaymentService.validateAllowed (COD kill-switch)', () => {
  const svc = new CashPaymentService({} as never);
  const original = process.env.COD_ENABLED;

  afterEach(() => {
    if (original === undefined) delete process.env.COD_ENABLED;
    else process.env.COD_ENABLED = original;
  });

  it('rejects cash with COD_DISABLED when COD_ENABLED is unset', () => {
    delete process.env.COD_ENABLED;
    expect(() => svc.validateAllowed('PICKUP' as never)).toThrow();
    try {
      svc.validateAllowed('DELIVERY' as never);
    } catch (e) {
      expect((e as { response?: { code?: string } }).response?.code).toBe('COD_DISABLED');
    }
  });

  it('rejects cash for any value other than the literal "true"', () => {
    for (const v of ['false', '1', 'TRUE', '']) {
      process.env.COD_ENABLED = v;
      expect(() => svc.validateAllowed('PICKUP' as never)).toThrow();
    }
  });

  it('allows cash for both fulfillment types when COD_ENABLED=true', () => {
    process.env.COD_ENABLED = 'true';
    expect(() => svc.validateAllowed('PICKUP' as never)).not.toThrow();
    expect(() => svc.validateAllowed('DELIVERY' as never)).not.toThrow();
  });
});
