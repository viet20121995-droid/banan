import { Injectable, NotFoundException } from '@nestjs/common';
import type { Address } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';

import type { CreateAddressDto, UpdateAddressDto } from './dto/address.dto';

@Injectable()
export class AddressesService {
  constructor(private readonly prisma: PrismaService) {}

  /** A user's address book — default first, then newest. */
  list(userId: string): Promise<Address[]> {
    return this.prisma.address.findMany({
      where: { userId },
      orderBy: [{ isDefault: 'desc' }, { id: 'desc' }],
    });
  }

  async create(userId: string, dto: CreateAddressDto): Promise<Address> {
    const count = await this.prisma.address.count({ where: { userId } });
    // First address is always the default; otherwise honour the flag.
    const makeDefault = count === 0 ? true : dto.isDefault === true;
    return this.prisma.$transaction(async (tx) => {
      if (makeDefault) {
        await tx.address.updateMany({
          where: { userId, isDefault: true },
          data: { isDefault: false },
        });
      }
      return tx.address.create({
        data: {
          userId,
          label: dto.label.trim(),
          recipient: dto.recipient.trim(),
          phone: dto.phone.trim(),
          line1: dto.line1.trim(),
          line2: dto.line2?.trim() || null,
          city: dto.city.trim(),
          district: dto.district?.trim() || null,
          wardCode: dto.wardCode?.trim() || null,
          postalCode: dto.postalCode?.trim() || null,
          isDefault: makeDefault,
        },
      });
    });
  }

  async update(userId: string, id: string, dto: UpdateAddressDto): Promise<Address> {
    await this.owned(userId, id);
    return this.prisma.$transaction(async (tx) => {
      if (dto.isDefault === true) {
        await tx.address.updateMany({
          where: { userId, isDefault: true },
          data: { isDefault: false },
        });
      }
      return tx.address.update({
        where: { id },
        data: {
          ...(dto.label !== undefined ? { label: dto.label.trim() } : {}),
          ...(dto.recipient !== undefined ? { recipient: dto.recipient.trim() } : {}),
          ...(dto.phone !== undefined ? { phone: dto.phone.trim() } : {}),
          ...(dto.line1 !== undefined ? { line1: dto.line1.trim() } : {}),
          ...(dto.line2 !== undefined ? { line2: dto.line2.trim() || null } : {}),
          ...(dto.city !== undefined ? { city: dto.city.trim() } : {}),
          ...(dto.district !== undefined ? { district: dto.district.trim() || null } : {}),
          ...(dto.wardCode !== undefined ? { wardCode: dto.wardCode.trim() || null } : {}),
          ...(dto.postalCode !== undefined ? { postalCode: dto.postalCode.trim() || null } : {}),
          ...(dto.isDefault === true ? { isDefault: true } : {}),
        },
      });
    });
  }

  async remove(userId: string, id: string): Promise<void> {
    const addr = await this.owned(userId, id);
    await this.prisma.$transaction(async (tx) => {
      await tx.address.delete({ where: { id } });
      if (addr.isDefault) {
        // Promote the next-newest address so the user always has a default.
        const next = await tx.address.findFirst({
          where: { userId },
          orderBy: { id: 'desc' },
        });
        if (next) {
          await tx.address.update({
            where: { id: next.id },
            data: { isDefault: true },
          });
        }
      }
    });
  }

  async setDefault(userId: string, id: string): Promise<Address> {
    await this.owned(userId, id);
    return this.prisma.$transaction(async (tx) => {
      await tx.address.updateMany({
        where: { userId, isDefault: true },
        data: { isDefault: false },
      });
      return tx.address.update({
        where: { id },
        data: { isDefault: true },
      });
    });
  }

  private async owned(userId: string, id: string): Promise<Address> {
    const addr = await this.prisma.address.findUnique({ where: { id } });
    if (!addr || addr.userId !== userId) {
      throw new NotFoundException({ code: 'ADDRESS_NOT_FOUND' });
    }
    return addr;
  }
}
