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
import { UpdateUserDto } from './dto/update-user.dto';

const MERCHANT_ROLES: ProvisionableRole[] = [
  ProvisionableRole.MERCHANT_OWNER,
  ProvisionableRole.MERCHANT_STAFF,
];
const KITCHEN_ROLES: ProvisionableRole[] = [
  ProvisionableRole.KITCHEN_MANAGER,
  ProvisionableRole.KITCHEN_STAFF,
];

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
      if (
        e instanceof Prisma.PrismaClientKnownRequestError &&
        e.code === 'P2002'
      ) {
        throw new ConflictException({
          code: 'EMAIL_TAKEN',
          message: 'An account with that email or phone already exists.',
        });
      }
      throw e;
    }
  }

  async listUsers(opts: {
    role?: string;
    q?: string;
    page: number;
    perPage: number;
  }) {
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
      dto.role !== undefined ||
      dto.storeId !== undefined ||
      dto.kitchenId !== undefined;
    if (touchesLinkage) {
      const isMerchant =
        nextRole === Role.MERCHANT_OWNER || nextRole === Role.MERCHANT_STAFF;
      const isKitchen =
        nextRole === Role.KITCHEN_MANAGER || nextRole === Role.KITCHEN_STAFF;
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
      if (
        e instanceof Prisma.PrismaClientKnownRequestError &&
        e.code === 'P2002'
      ) {
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
    const passwordHash = await bcrypt.hash(password, 10);
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

  listStores() {
    return this.prisma.store.findMany({
      orderBy: { name: 'asc' },
      select: { id: true, name: true },
    });
  }

  listKitchens() {
    return this.prisma.kitchen.findMany({
      orderBy: { name: 'asc' },
      select: { id: true, name: true },
    });
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
