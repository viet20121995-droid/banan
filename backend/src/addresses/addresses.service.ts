import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import type { Address } from '@prisma/client';

import { canonicalWardCode, isAmbiguousLegacyWard } from '../geo/hcm-wards';
import { PrismaService } from '../prisma/prisma.service';

import type { CreateAddressDto, UpdateAddressDto } from './dto/address.dto';

@Injectable()
export class AddressesService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Validates + canonicalizes a wardCode before it hits the address row:
   * safe legacy aliases are rewritten to the new canonical code, split-ward
   * codes are refused (the customer must re-pick — never guessed), and
   * unknown codes are rejected outright. Empty/omitted stays null.
   */
  private normalizeWardCode(raw: string | undefined): string | null {
    const code = raw?.trim();
    if (!code) return null;
    if (isAmbiguousLegacyWard(code)) {
      throw new BadRequestException({
        code: 'WARD_RESELECTION_REQUIRED',
        message:
          'Phường cũ đã được chia tách sau sắp xếp hành chính. Vui lòng chọn lại phường/xã mới.',
      });
    }
    const canonical = canonicalWardCode(code);
    if (!canonical) {
      throw new BadRequestException({
        code: 'WARD_NOT_FOUND',
        message: 'Phường/xã không hợp lệ. Vui lòng chọn lại từ danh sách.',
      });
    }
    return canonical;
  }

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
          wardCode: this.normalizeWardCode(dto.wardCode),
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
          ...(dto.wardCode !== undefined ? { wardCode: this.normalizeWardCode(dto.wardCode) } : {}),
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
