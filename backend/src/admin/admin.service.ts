import {
  BadRequestException,
  ConflictException,
  Injectable,
} from '@nestjs/common';
import { Prisma, Role } from '@prisma/client';
import bcrypt from 'bcrypt';

import { PrismaService } from '../prisma/prisma.service';

import { CreateUserDto, ProvisionableRole } from './dto/create-user.dto';

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

    const passwordHash = await bcrypt.hash(dto.password, 10);
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
      storeId: u.storeId,
      kitchenId: u.kitchenId,
      createdAt: u.createdAt.toISOString(),
    };
  }
}
