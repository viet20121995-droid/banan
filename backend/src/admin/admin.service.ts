import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma, Role } from '@prisma/client';
import bcrypt from 'bcrypt';

import { PrismaService } from '../prisma/prisma.service';

import { CreateUserDto, ProvisionableRole } from './dto/create-user.dto';
import { CreateKitchenDto, UpdateKitchenDto } from './dto/kitchen.dto';
import { CreateStoreDto, UpdateStoreDto } from './dto/store.dto';
import { UpdateUserDto } from './dto/update-user.dto';

const MERCHANT_ROLES: ProvisionableRole[] = [
  ProvisionableRole.MERCHANT_OWNER,
  ProvisionableRole.MERCHANT_STAFF,
];
const KITCHEN_ROLES: ProvisionableRole[] = [
  ProvisionableRole.KITCHEN_MANAGER,
  ProvisionableRole.KITCHEN_STAFF,
];

/** Opening hours seeded onto a freshly-created branch (08:00–21:00 every day).
 *  The merchant fine-tunes these afterwards via the store-settings screen; the
 *  column is required (no DB default) so admin store-create must always set it. */
const DEFAULT_OPENING_HOURS: Prisma.InputJsonValue = {
  mon: [['08:00', '21:00']],
  tue: [['08:00', '21:00']],
  wed: [['08:00', '21:00']],
  thu: [['08:00', '21:00']],
  fri: [['08:00', '21:00']],
  sat: [['08:00', '21:00']],
  sun: [['08:00', '21:00']],
};

@Injectable()
export class AdminService {
  constructor(private readonly prisma: PrismaService) {}

  /** Create a sub-account (merchant / kitchen / customer). */
  async createUser(dto: CreateUserDto) {
    const isMerchant = MERCHANT_ROLES.includes(dto.role);
    const isKitchen = KITCHEN_ROLES.includes(dto.role);

    if (isMerchant) {
      if (!dto.storeId) {
        throw new BadRequestException({
          code: 'STORE_REQUIRED',
          message: 'Merchant accounts must be assigned to a store.',
        });
      }
      const store = await this.prisma.store.findUnique({
        where: { id: dto.storeId },
        select: { id: true },
      });
      if (!store) {
        throw new BadRequestException({ code: 'STORE_NOT_FOUND' });
      }
    }
    if (isKitchen) {
      if (!dto.kitchenId) {
        throw new BadRequestException({
          code: 'KITCHEN_REQUIRED',
          message: 'Kitchen accounts must be assigned to a kitchen.',
        });
      }
      const kitchen = await this.prisma.kitchen.findUnique({
        where: { id: dto.kitchenId },
        select: { id: true },
      });
      if (!kitchen) {
        throw new BadRequestException({ code: 'KITCHEN_NOT_FOUND' });
      }
    }

    const passwordHash = await bcrypt.hash(dto.password, 12);
    try {
      const user = await this.prisma.user.create({
        data: {
          email: dto.email.toLowerCase(),
          phone: dto.phone || null,
          passwordHash,
          fullName: dto.fullName.trim(),
          role: dto.role as Role,
          storeId: isMerchant ? dto.storeId : null,
          kitchenId: isKitchen ? dto.kitchenId : null,
          // Admin-provisioned, login-capable account → owner-controlled, so it
          // must never be silently reused as a guest-checkout target.
          claimed: true,
        },
      });
      return AdminService.view(user);
    } catch (e) {
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
        throw new ConflictException({
          code: 'EMAIL_TAKEN',
          message: 'An account with that email or phone already exists.',
        });
      }
      throw e;
    }
  }

  async listUsers(opts: { role?: string; q?: string; page: number; perPage: number }) {
    const where: Prisma.UserWhereInput = {};
    if (opts.role && opts.role in Role) {
      where.role = opts.role as Role;
    }
    const q = opts.q?.trim();
    if (q) {
      where.OR = [
        { fullName: { contains: q, mode: 'insensitive' } },
        { email: { contains: q, mode: 'insensitive' } },
        { phone: { contains: q } },
      ];
    }
    const total = await this.prisma.user.count({ where });
    const users = await this.prisma.user.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      skip: (opts.page - 1) * opts.perPage,
      take: opts.perPage,
      include: {
        store: { select: { name: true } },
        kitchen: { select: { name: true } },
      },
    });
    return {
      items: users.map((u) => ({
        ...AdminService.view(u),
        storeName: u.store?.name ?? null,
        kitchenName: u.kitchen?.name ?? null,
      })),
      meta: { page: opts.page, perPage: opts.perPage, total },
    };
  }

  async getUser(id: string) {
    const u = await this.prisma.user.findUnique({
      where: { id },
      include: {
        store: { select: { name: true } },
        kitchen: { select: { name: true } },
      },
    });
    if (!u) throw new NotFoundException({ code: 'USER_NOT_FOUND' });
    return {
      ...AdminService.view(u),
      storeName: u.store?.name ?? null,
      kitchenName: u.kitchen?.name ?? null,
    };
  }

  /** Edit an existing user. ADMIN accounts are not editable through here. */
  async updateUser(id: string, dto: UpdateUserDto) {
    const existing = await this.prisma.user.findUnique({ where: { id } });
    if (!existing) throw new NotFoundException({ code: 'USER_NOT_FOUND' });
    if (existing.role === Role.ADMIN) {
      throw new BadRequestException({
        code: 'CANNOT_EDIT_ADMIN',
        message: 'Tài khoản ADMIN được quản lý riêng, không sửa tại đây.',
      });
    }

    const data: Prisma.UserUncheckedUpdateInput = {};
    if (dto.fullName !== undefined) data.fullName = dto.fullName.trim();
    if (dto.email !== undefined) data.email = dto.email.toLowerCase();
    if (dto.phone !== undefined) {
      const p = dto.phone.trim();
      data.phone = p.length === 0 ? null : p;
    }
    if (dto.isActive !== undefined) data.isActive = dto.isActive;

    // Keep role + store/kitchen linkage consistent.
    const nextRole = (dto.role as unknown as Role) ?? existing.role;
    if (dto.role !== undefined) data.role = nextRole;

    const touchesLinkage =
      dto.role !== undefined || dto.storeId !== undefined || dto.kitchenId !== undefined;
    if (touchesLinkage) {
      const isMerchant = nextRole === Role.MERCHANT_OWNER || nextRole === Role.MERCHANT_STAFF;
      const isKitchen = nextRole === Role.KITCHEN_MANAGER || nextRole === Role.KITCHEN_STAFF;
      if (isMerchant) {
        const storeId = dto.storeId ?? existing.storeId;
        if (!storeId) {
          throw new BadRequestException({
            code: 'STORE_REQUIRED',
            message: 'Tài khoản merchant phải thuộc một cửa hàng.',
          });
        }
        const store = await this.prisma.store.findUnique({
          where: { id: storeId },
          select: { id: true },
        });
        if (!store) throw new BadRequestException({ code: 'STORE_NOT_FOUND' });
        data.storeId = storeId;
        data.kitchenId = null;
      } else if (isKitchen) {
        const kitchenId = dto.kitchenId ?? existing.kitchenId;
        if (!kitchenId) {
          throw new BadRequestException({
            code: 'KITCHEN_REQUIRED',
            message: 'Tài khoản bếp phải thuộc một bếp.',
          });
        }
        const kitchen = await this.prisma.kitchen.findUnique({
          where: { id: kitchenId },
          select: { id: true },
        });
        if (!kitchen) {
          throw new BadRequestException({ code: 'KITCHEN_NOT_FOUND' });
        }
        data.kitchenId = kitchenId;
        data.storeId = null;
      } else {
        // CUSTOMER — clear staff linkage.
        data.storeId = null;
        data.kitchenId = null;
      }
    }

    try {
      const user = await this.prisma.user.update({ where: { id }, data });
      return AdminService.view(user);
    } catch (e) {
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
        throw new ConflictException({
          code: 'EMAIL_TAKEN',
          message: 'Email hoặc số điện thoại đã được dùng.',
        });
      }
      throw e;
    }
  }

  /** Admin sets a new password for a user + revokes their active sessions. */
  async resetUserPassword(id: string, password: string) {
    const existing = await this.prisma.user.findUnique({ where: { id } });
    if (!existing) throw new NotFoundException({ code: 'USER_NOT_FOUND' });
    const passwordHash = await bcrypt.hash(password, 12);
    await this.prisma.$transaction([
      this.prisma.user.update({ where: { id }, data: { passwordHash } }),
      this.prisma.refreshToken.updateMany({
        where: { userId: id, revokedAt: null },
        data: { revokedAt: new Date() },
      }),
    ]);
    return { ok: true };
  }

  /** Soft-delete: disable login (keeps order history) + revoke sessions.
   *  Admins can't disable themselves or other ADMIN accounts. */
  async deactivateUser(id: string, actingAdminId: string) {
    if (id === actingAdminId) {
      throw new BadRequestException({
        code: 'CANNOT_DISABLE_SELF',
        message: 'Không thể khóa chính tài khoản của bạn.',
      });
    }
    const existing = await this.prisma.user.findUnique({ where: { id } });
    if (!existing) throw new NotFoundException({ code: 'USER_NOT_FOUND' });
    if (existing.role === Role.ADMIN) {
      throw new BadRequestException({
        code: 'CANNOT_DISABLE_ADMIN',
        message: 'Không thể khóa tài khoản ADMIN.',
      });
    }
    await this.prisma.$transaction([
      this.prisma.user.update({ where: { id }, data: { isActive: false } }),
      this.prisma.refreshToken.updateMany({
        where: { userId: id, revokedAt: null },
        data: { revokedAt: new Date() },
      }),
    ]);
    return { ok: true };
  }

  /** Full store rows (all scalar fields) — the admin stores screen needs the
   *  identity fields to hydrate the editor; OrgOption dropdowns just read
   *  id+name from the same payload. */
  listStores() {
    return this.prisma.store.findMany({ orderBy: { name: 'asc' } });
  }

  listKitchens() {
    return this.prisma.kitchen.findMany({
      orderBy: { name: 'asc' },
      select: { id: true, name: true, address: true, capacityPerHour: true },
    });
  }

  // ───────────────────────── Stores (chain branches) ─────────────────────────

  /** Create a new branch. Identity only — opening hours seeded to a default;
   *  pause/min-order/lead settings keep their schema defaults and are tuned via
   *  the store-settings screen. */
  async createStore(dto: CreateStoreDto) {
    await this.assertKitchenExists(dto.defaultKitchenId);
    try {
      return await this.prisma.store.create({
        data: {
          name: dto.name.trim(),
          slug: dto.slug.trim(),
          address: dto.address.trim(),
          phone: dto.phone.trim(),
          wardCode: dto.wardCode?.trim() || null,
          defaultKitchenId: dto.defaultKitchenId ?? null,
          lat: dto.lat ?? null,
          lng: dto.lng ?? null,
          openingHours: DEFAULT_OPENING_HOURS,
        },
      });
    } catch (e) {
      this.rethrowStoreSlug(e);
    }
  }

  async updateStore(id: string, dto: UpdateStoreDto) {
    const existing = await this.prisma.store.findUnique({
      where: { id },
      select: { id: true },
    });
    if (!existing) throw new NotFoundException({ code: 'STORE_NOT_FOUND' });

    const data: Prisma.StoreUncheckedUpdateInput = {};
    if (dto.name !== undefined) data.name = dto.name.trim();
    if (dto.slug !== undefined) data.slug = dto.slug.trim();
    if (dto.address !== undefined) data.address = dto.address.trim();
    if (dto.phone !== undefined) data.phone = dto.phone.trim();
    if (dto.wardCode !== undefined) data.wardCode = dto.wardCode.trim() || null;
    if (dto.lat !== undefined) data.lat = dto.lat;
    if (dto.lng !== undefined) data.lng = dto.lng;
    if (dto.defaultKitchenId !== undefined) {
      // null detaches the default kitchen; a value must reference a real one.
      await this.assertKitchenExists(dto.defaultKitchenId ?? undefined);
      data.defaultKitchenId = dto.defaultKitchenId;
    }

    try {
      return await this.prisma.store.update({ where: { id }, data });
    } catch (e) {
      this.rethrowStoreSlug(e);
    }
  }

  /** Hard-delete a branch. Blocked (clean 400) if anything still references it,
   *  since every back-relation is RESTRICT (a raw delete would 500 on the FK).
   *  Blackout dates cascade, so they don't count as blockers. */
  async deleteStore(id: string) {
    const existing = await this.prisma.store.findUnique({
      where: { id },
      select: { id: true },
    });
    if (!existing) throw new NotFoundException({ code: 'STORE_NOT_FOUND' });

    const [users, products, orders, collections, bundles, threads, coupons, banners] =
      await this.prisma.$transaction([
        this.prisma.user.count({ where: { storeId: id } }),
        this.prisma.product.count({ where: { storeId: id } }),
        this.prisma.order.count({ where: { storeId: id } }),
        this.prisma.collection.count({ where: { storeId: id } }),
        this.prisma.bundle.count({ where: { storeId: id } }),
        this.prisma.thread.count({ where: { storeId: id } }),
        this.prisma.coupon.count({ where: { storeId: id } }),
        this.prisma.banner.count({ where: { storeId: id } }),
      ]);
    if (users || products || orders || collections || bundles || threads || coupons || banners) {
      throw new BadRequestException({
        code: 'STORE_IN_USE',
        message:
          'Không thể xoá cửa hàng đang có dữ liệu liên kết (nhân viên / sản phẩm / đơn hàng…). ' +
          'Hãy chuyển hoặc gỡ các dữ liệu đó trước.',
        counts: { users, products, orders, collections, bundles, threads, coupons, banners },
      });
    }
    await this.prisma.store.delete({ where: { id } });
    return { ok: true };
  }

  // ──────────────────────────── Kitchens (prep) ──────────────────────────────

  async createKitchen(dto: CreateKitchenDto) {
    return this.prisma.kitchen.create({
      data: {
        name: dto.name.trim(),
        address: dto.address.trim(),
        capacityPerHour: dto.capacityPerHour ?? 40,
      },
    });
  }

  async updateKitchen(id: string, dto: UpdateKitchenDto) {
    const existing = await this.prisma.kitchen.findUnique({
      where: { id },
      select: { id: true },
    });
    if (!existing) throw new NotFoundException({ code: 'KITCHEN_NOT_FOUND' });

    const data: Prisma.KitchenUncheckedUpdateInput = {};
    if (dto.name !== undefined) data.name = dto.name.trim();
    if (dto.address !== undefined) data.address = dto.address.trim();
    if (dto.capacityPerHour !== undefined) data.capacityPerHour = dto.capacityPerHour;
    return this.prisma.kitchen.update({ where: { id }, data });
  }

  /** Hard-delete a kitchen. Blocked if staff are assigned, a store uses it as
   *  default, or it has production batches / orders (all RESTRICT). */
  async deleteKitchen(id: string) {
    const existing = await this.prisma.kitchen.findUnique({
      where: { id },
      select: { id: true },
    });
    if (!existing) throw new NotFoundException({ code: 'KITCHEN_NOT_FOUND' });

    const [users, defaultForStores, batches, orders] = await this.prisma.$transaction([
      this.prisma.user.count({ where: { kitchenId: id } }),
      this.prisma.store.count({ where: { defaultKitchenId: id } }),
      this.prisma.productionBatch.count({ where: { kitchenId: id } }),
      this.prisma.order.count({ where: { kitchenId: id } }),
    ]);
    if (users || defaultForStores || batches || orders) {
      throw new BadRequestException({
        code: 'KITCHEN_IN_USE',
        message:
          'Không thể xoá bếp đang được sử dụng (nhân viên / là bếp mặc định của cửa hàng / ' +
          'mẻ sản xuất / đơn hàng).',
        counts: { users, defaultForStores, batches, orders },
      });
    }
    await this.prisma.kitchen.delete({ where: { id } });
    return { ok: true };
  }

  /** Validates a referenced kitchen exists (skips null/undefined). */
  private async assertKitchenExists(kitchenId: string | null | undefined) {
    if (!kitchenId) return;
    const kitchen = await this.prisma.kitchen.findUnique({
      where: { id: kitchenId },
      select: { id: true },
    });
    if (!kitchen) {
      throw new BadRequestException({
        code: 'KITCHEN_NOT_FOUND',
        message: 'Bếp được chọn không tồn tại (có thể vừa bị xoá).',
      });
    }
  }

  /** Store.slug is @unique — a duplicate surfaces as Prisma P2002. */
  private rethrowStoreSlug(e: unknown): never {
    if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
      throw new ConflictException({
        code: 'STORE_SLUG_TAKEN',
        message: 'Slug cửa hàng đã tồn tại — vui lòng chọn slug khác.',
      });
    }
    throw e;
  }

  private static view(u: {
    id: string;
    email: string;
    phone: string | null;
    fullName: string;
    role: Role;
    isActive: boolean;
    storeId: string | null;
    kitchenId: string | null;
    createdAt: Date;
  }) {
    return {
      id: u.id,
      email: u.email,
      phone: u.phone,
      fullName: u.fullName,
      role: u.role,
      isActive: u.isActive,
      storeId: u.storeId,
      kitchenId: u.kitchenId,
      createdAt: u.createdAt.toISOString(),
    };
  }
}
