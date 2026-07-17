import { BadRequestException } from '@nestjs/common';

import { CategoriesService } from './categories.service';

// Force-delete must protect order history: a category whose products appear in
// any order cannot be hard-deleted (OrderItem.product is Restrict), so
// removeWithProducts refuses the WHOLE operation instead of partially wiping.
describe('CategoriesService.removeWithProducts (order-safety)', () => {
  function make(opts: { orderRefs: number; productIds?: string[] }) {
    const category = { delete: jest.fn().mockResolvedValue({}) };
    const prisma = {
      category: {
        findUnique: jest.fn().mockResolvedValue({ id: 'c1', name: 'X' }),
        delete: category.delete,
      },
      product: {
        findMany: jest.fn().mockResolvedValue((opts.productIds ?? ['p1']).map((id) => ({ id }))),
      },
      orderItem: { count: jest.fn().mockResolvedValue(opts.orderRefs) },
    };
    const products = { remove: jest.fn().mockResolvedValue({ deleted: true }) };
    const svc = new CategoriesService(prisma as never, products as never);
    return { svc, prisma, products };
  }

  it('refuses when any product is already in an order (keeps history)', async () => {
    const { svc, products, prisma } = make({ orderRefs: 2 });
    await expect(svc.removeWithProducts('c1', null)).rejects.toBeInstanceOf(BadRequestException);
    expect(products.remove).not.toHaveBeenCalled();
    expect(prisma.category.delete).not.toHaveBeenCalled();
  });

  it('hard-deletes every order-free product then the category', async () => {
    const { svc, products, prisma } = make({
      orderRefs: 0,
      productIds: ['p1', 'p2'],
    });
    await svc.removeWithProducts('c1', null);
    expect(products.remove).toHaveBeenCalledTimes(2);
    expect(products.remove).toHaveBeenCalledWith('p1', null);
    expect(products.remove).toHaveBeenCalledWith('p2', null);
    expect(prisma.category.delete).toHaveBeenCalledWith({ where: { id: 'c1' } });
  });
});
