import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';
import { assertPrivateFileName } from '../files/internal-files.util';

import type {
  AssignPathDto,
  CreateMaterialDto,
  CreatePathDto,
  CreatePersonDto,
  PeopleQueryDto,
  ProgressQueryDto,
  UpdateMaterialDto,
  UpdatePathDto,
  UpdatePersonDto,
  UpdateProgressDto,
} from './dto';

const DAY_MS = 86_400_000;

@Injectable()
export class TrainingService {
  constructor(private readonly prisma: PrismaService) {}

  // ── people ────────────────────────────────────────────────────────────────

  async createPerson(dto: CreatePersonDto, actorId: string) {
    const store = await this.prisma.store.findUnique({ where: { id: dto.storeId } });
    if (!store) this.badStore();
    const person = await this.prisma.internalPerson.create({
      data: {
        fullName: dto.fullName.trim(),
        storeId: dto.storeId,
        position: dto.position.trim(),
        startDate: dto.startDate ? new Date(dto.startDate) : null,
        notes: dto.notes?.trim() || null,
        createdById: actorId,
        transfers: {
          create: { fromStoreId: null, toStoreId: dto.storeId, changedById: actorId },
        },
      },
      include: { store: { select: { id: true, name: true } } },
    });
    return person;
  }

  async updatePerson(id: string, dto: UpdatePersonDto, actorId: string) {
    const person = await this.prisma.internalPerson.findUnique({ where: { id } });
    if (!person) this.notFound('INTERNAL_TRAINING_PERSON_NOT_FOUND', 'Không tìm thấy nhân sự.');
    if (dto.storeId && dto.storeId !== person.storeId) {
      const store = await this.prisma.store.findUnique({ where: { id: dto.storeId } });
      if (!store) this.badStore();
      // Transfer keeps history — one append-only row per move.
      await this.prisma.internalPersonTransfer.create({
        data: {
          personId: id,
          fromStoreId: person.storeId,
          toStoreId: dto.storeId,
          changedById: actorId,
        },
      });
    }
    return this.prisma.internalPerson.update({
      where: { id },
      data: {
        ...(dto.fullName !== undefined && { fullName: dto.fullName.trim() }),
        ...(dto.storeId !== undefined && { storeId: dto.storeId }),
        ...(dto.position !== undefined && { position: dto.position.trim() }),
        ...(dto.startDate !== undefined && {
          startDate: dto.startDate ? new Date(dto.startDate) : null,
        }),
        ...(dto.isActive !== undefined && { isActive: dto.isActive }),
        ...(dto.notes !== undefined && { notes: dto.notes?.trim() || null }),
      },
      include: {
        store: { select: { id: true, name: true } },
        transfers: { orderBy: { changedAt: 'asc' } },
      },
    });
  }

  async listPeople(query: PeopleQueryDto) {
    return this.prisma.internalPerson.findMany({
      where: {
        ...(query.storeId && { storeId: query.storeId }),
        ...(query.active && { isActive: query.active === 'true' }),
        ...(query.position && { position: { contains: query.position, mode: 'insensitive' } }),
        ...(query.q && { fullName: { contains: query.q, mode: 'insensitive' } }),
      },
      include: { store: { select: { id: true, name: true } } },
      orderBy: [{ isActive: 'desc' }, { fullName: 'asc' }],
    });
  }

  async personDetail(id: string) {
    const person = await this.prisma.internalPerson.findUnique({
      where: { id },
      include: {
        store: { select: { id: true, name: true } },
        transfers: { orderBy: { changedAt: 'asc' } },
        trainingAssignments: {
          include: {
            path: { select: { id: true, name: true } },
            progress: { include: { pathItem: { include: { material: true } } } },
          },
        },
      },
    });
    if (!person) this.notFound('INTERNAL_TRAINING_PERSON_NOT_FOUND', 'Không tìm thấy nhân sự.');
    return {
      ...person,
      trainingAssignments: person.trainingAssignments.map((a) => this.assignmentView(a)),
    };
  }

  // ── materials ─────────────────────────────────────────────────────────────

  async createMaterial(dto: CreateMaterialDto, actorId: string) {
    this.validateMaterialUrl(dto.kind, dto.url);
    return this.prisma.trainingMaterial.create({
      data: {
        title: dto.title.trim(),
        description: dto.description?.trim() || null,
        category: dto.category,
        kind: dto.kind,
        url: dto.url?.trim() || null,
        isRequired: dto.isRequired ?? false,
        estimatedMinutes: dto.estimatedMinutes ?? null,
        effectiveFrom: dto.effectiveFrom ? new Date(dto.effectiveFrom) : null,
        createdById: actorId,
      },
    });
  }

  /** Metadata-only edits. Content changes go through reissue() so the old
   *  version stays traceable. */
  async updateMaterial(id: string, dto: UpdateMaterialDto) {
    await this.materialById(id);
    return this.prisma.trainingMaterial.update({
      where: { id },
      data: {
        ...(dto.title !== undefined && { title: dto.title.trim() }),
        ...(dto.description !== undefined && { description: dto.description?.trim() || null }),
        ...(dto.isActive !== undefined && { isActive: dto.isActive }),
        ...(dto.isRequired !== undefined && { isRequired: dto.isRequired }),
        ...(dto.estimatedMinutes !== undefined && { estimatedMinutes: dto.estimatedMinutes }),
      },
    });
  }

  /** New content = NEW row (version+1), old row deactivated but kept. */
  async reissueMaterial(id: string, dto: CreateMaterialDto, actorId: string) {
    const old = await this.materialById(id);
    this.validateMaterialUrl(dto.kind, dto.url);
    const [, fresh] = await this.prisma.$transaction([
      this.prisma.trainingMaterial.update({ where: { id }, data: { isActive: false } }),
      this.prisma.trainingMaterial.create({
        data: {
          title: dto.title.trim(),
          description: dto.description?.trim() || null,
          category: dto.category,
          kind: dto.kind,
          url: dto.url?.trim() || null,
          isRequired: dto.isRequired ?? old.isRequired,
          estimatedMinutes: dto.estimatedMinutes ?? old.estimatedMinutes,
          effectiveFrom: dto.effectiveFrom ? new Date(dto.effectiveFrom) : new Date(),
          version: old.version + 1,
          supersedesId: old.id,
          createdById: actorId,
        },
      }),
    ]);
    return fresh;
  }

  listMaterials(category?: string, activeOnly = true) {
    return this.prisma.trainingMaterial.findMany({
      where: {
        ...(category && { category: category as never }),
        ...(activeOnly && { isActive: true }),
      },
      orderBy: [{ category: 'asc' }, { title: 'asc' }, { version: 'desc' }],
    });
  }

  // ── paths ─────────────────────────────────────────────────────────────────

  async createPath(dto: CreatePathDto, actorId: string) {
    if (dto.items.length === 0) {
      throw new BadRequestException({
        code: 'INTERNAL_TRAINING_PATH_EMPTY',
        message: 'Lộ trình cần ít nhất một bài.',
      });
    }
    await this.assertMaterialsExist(dto.items.map((i) => i.materialId));
    return this.prisma.trainingPath.create({
      data: {
        name: dto.name.trim(),
        position: dto.position?.trim() || null,
        createdById: actorId,
        items: {
          create: dto.items.map((i, idx) => ({
            materialId: i.materialId,
            sortOrder: idx,
            isRequired: i.isRequired ?? true,
            dueDays: i.dueDays ?? null,
          })),
        },
      },
      include: { items: { include: { material: true }, orderBy: { sortOrder: 'asc' } } },
    });
  }

  async updatePath(id: string, dto: UpdatePathDto) {
    const path = await this.prisma.trainingPath.findUnique({
      where: { id },
      include: { assignments: { select: { id: true }, take: 1 } },
    });
    if (!path) this.notFound('INTERNAL_TRAINING_PATH_NOT_FOUND', 'Không tìm thấy lộ trình.');
    if (dto.items) {
      if (path.assignments.length > 0) {
        // Progress rows reference the items — replacing them would orphan
        // history. Admin makes a new path instead.
        throw new BadRequestException({
          code: 'INTERNAL_TRAINING_PATH_IN_USE',
          message: 'Lộ trình đã được gán — tạo lộ trình mới thay vì sửa danh sách bài.',
        });
      }
      await this.assertMaterialsExist(dto.items.map((i) => i.materialId));
      await this.prisma.$transaction([
        this.prisma.trainingPathItem.deleteMany({ where: { pathId: id } }),
        this.prisma.trainingPathItem.createMany({
          data: dto.items.map((i, idx) => ({
            pathId: id,
            materialId: i.materialId,
            sortOrder: idx,
            isRequired: i.isRequired ?? true,
            dueDays: i.dueDays ?? null,
          })),
        }),
      ]);
    }
    return this.prisma.trainingPath.update({
      where: { id },
      data: {
        ...(dto.name !== undefined && { name: dto.name.trim() }),
        ...(dto.position !== undefined && { position: dto.position?.trim() || null }),
        ...(dto.isActive !== undefined && { isActive: dto.isActive }),
      },
      include: { items: { include: { material: true }, orderBy: { sortOrder: 'asc' } } },
    });
  }

  listPaths() {
    return this.prisma.trainingPath.findMany({
      include: {
        items: { include: { material: true }, orderBy: { sortOrder: 'asc' } },
        _count: { select: { assignments: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  // ── assignments + progress ────────────────────────────────────────────────

  async assign(dto: AssignPathDto, actorId: string) {
    const [person, path] = await Promise.all([
      this.prisma.internalPerson.findUnique({ where: { id: dto.personId } }),
      this.prisma.trainingPath.findUnique({
        where: { id: dto.pathId },
        include: { items: true },
      }),
    ]);
    if (!person) this.notFound('INTERNAL_TRAINING_PERSON_NOT_FOUND', 'Không tìm thấy nhân sự.');
    if (!path) this.notFound('INTERNAL_TRAINING_PATH_NOT_FOUND', 'Không tìm thấy lộ trình.');
    try {
      const assignment = await this.prisma.trainingAssignment.create({
        data: {
          personId: dto.personId,
          pathId: dto.pathId,
          startDate: new Date(dto.startDate),
          assignedById: actorId,
          progress: {
            create: path.items.map((i) => ({ pathItemId: i.id })),
          },
        },
        include: {
          path: { select: { id: true, name: true } },
          progress: { include: { pathItem: { include: { material: true } } } },
        },
      });
      return this.assignmentView(assignment);
    } catch (e) {
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
        throw new BadRequestException({
          code: 'INTERNAL_TRAINING_ALREADY_ASSIGNED',
          message: 'Nhân sự đã được gán lộ trình này.',
        });
      }
      throw e;
    }
  }

  async updateProgress(progressId: string, dto: UpdateProgressDto, actorId: string) {
    const progress = await this.prisma.trainingProgress.findUnique({ where: { id: progressId } });
    if (!progress) {
      this.notFound('INTERNAL_TRAINING_PROGRESS_NOT_FOUND', 'Không tìm thấy tiến độ.');
    }
    return this.prisma.trainingProgress.update({
      where: { id: progressId },
      data: {
        ...(dto.status !== undefined && {
          status: dto.status,
          completedAt: dto.status === 'COMPLETED' ? new Date() : null,
          confirmedById: dto.status === 'COMPLETED' ? actorId : null,
        }),
        ...(dto.quizScore !== undefined && {
          quizScore: dto.quizScore,
          attempts: { increment: 1 },
        }),
        ...(dto.notes !== undefined && { notes: dto.notes?.trim() || null }),
      },
      include: { pathItem: { include: { material: true } } },
    });
  }

  /** Cross-people progress board with completion % and overdue detection. */
  async progressOverview(query: ProgressQueryDto) {
    const assignments = await this.prisma.trainingAssignment.findMany({
      where: {
        ...(query.personId && { personId: query.personId }),
        ...(query.storeId && { person: { storeId: query.storeId } }),
      },
      include: {
        person: {
          include: { store: { select: { id: true, name: true } } },
        },
        path: { select: { id: true, name: true } },
        progress: { include: { pathItem: { include: { material: true } } } },
      },
      orderBy: { createdAt: 'desc' },
    });
    let rows = assignments.map((a) => this.assignmentView(a));
    if (query.status) {
      rows = rows
        .map((r) => ({
          ...r,
          progress: r.progress.filter((p) => p.effectiveStatus === query.status),
        }))
        .filter((r) => r.progress.length > 0);
    }
    if (query.overdue === 'true') {
      rows = rows.filter((r) => r.overdueCount > 0);
    }
    return rows;
  }

  // ── trainee self-service (scoped to the caller's own InternalPerson) ─────

  /** The caller's linked person + their own assignments/progress. A user
   *  with no linked InternalPerson gets an explicit empty state, never an
   *  error — admin may not have linked them yet. */
  async meOverview(userId: string) {
    const person = await this.prisma.internalPerson.findUnique({
      where: { userId },
      include: { store: { select: { id: true, name: true } } },
    });
    if (!person) return { person: null, assignments: [] };
    const assignments = await this.prisma.trainingAssignment.findMany({
      where: { personId: person.id },
      include: {
        path: { select: { id: true, name: true } },
        progress: { include: { pathItem: { include: { material: true } } } },
      },
      orderBy: { createdAt: 'desc' },
    });
    return {
      person: {
        id: person.id,
        fullName: person.fullName,
        position: person.position,
        store: person.store,
      },
      assignments: assignments.map((a) => this.assignmentView(a)),
    };
  }

  /**
   * Own-progress update, status only. IDOR-proof: the progress row is
   * looked up THROUGH the caller's person link — someone else's id simply
   * doesn't match the where clause and 404s.
   *
   * A trainee saying "COMPLETED" only means "I'm done" — it lands as
   * PENDING_CONFIRMATION. COMPLETED (with completedAt + confirmedById) is
   * exclusively the ADMIN confirmation via updateProgress.
   */
  async updateOwnProgress(progressId: string, status: 'IN_PROGRESS' | 'COMPLETED', userId: string) {
    // ONE guarded write: ownership (through the person link) AND
    // not-yet-confirmed, both enforced atomically — an admin confirmation
    // landing between a read and a write can never be wiped back.
    const claimed = await this.prisma.trainingProgress.updateMany({
      where: {
        id: progressId,
        status: { not: 'COMPLETED' },
        assignment: { person: { userId } },
      },
      data: {
        status: status === 'COMPLETED' ? 'PENDING_CONFIRMATION' : 'IN_PROGRESS',
        completedAt: null,
        confirmedById: null,
      },
    });
    if (claimed.count === 0) {
      // Distinguish "not yours / doesn't exist" from "admin already
      // confirmed" — still through the ownership filter.
      const mine = await this.prisma.trainingProgress.findFirst({
        where: { id: progressId, assignment: { person: { userId } } },
        select: { status: true },
      });
      if (!mine) {
        this.notFound('INTERNAL_TRAINING_PROGRESS_NOT_FOUND', 'Không tìm thấy tiến độ.');
      }
      throw new BadRequestException({
        code: 'INTERNAL_TRAINING_ALREADY_CONFIRMED',
        message: 'Mục này đã được xác nhận hoàn thành.',
      });
    }
    return this.prisma.trainingProgress.findUniqueOrThrow({
      where: { id: progressId },
      include: { pathItem: { include: { material: true } } },
    });
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  private assignmentView(a: {
    id: string;
    personId: string;
    startDate: Date;
    path: { id: string; name: string };
    person?: {
      id: string;
      fullName: string;
      isActive: boolean;
      store: { id: string; name: string };
    };
    progress: {
      id: string;
      status: string;
      completedAt: Date | null;
      quizScore: number | null;
      attempts: number;
      notes: string | null;
      pathItem: {
        id: string;
        sortOrder: number;
        isRequired: boolean;
        dueDays: number | null;
        material: {
          id: string;
          title: string;
          category: string;
          kind: string;
          url: string | null;
          version: number;
        };
      };
    }[];
  }) {
    const now = Date.now();
    const progress = [...a.progress]
      .sort((x, y) => x.pathItem.sortOrder - y.pathItem.sortOrder)
      .map((p) => {
        const dueAt =
          p.pathItem.dueDays != null
            ? new Date(a.startDate.getTime() + p.pathItem.dueDays * DAY_MS)
            : null;
        // PENDING_CONFIRMATION is the trainee having finished — only the
        // admin sign-off is missing, so it never counts as overdue.
        const overdue =
          !['COMPLETED', 'PENDING_CONFIRMATION'].includes(p.status) &&
          dueAt != null &&
          dueAt.getTime() < now;
        return {
          id: p.id,
          status: p.status,
          // EXPIRED is derived, never stored — the deadline moves if admin
          // corrects startDate, and history stays truthful.
          effectiveStatus: overdue ? 'EXPIRED' : p.status,
          completedAt: p.completedAt?.toISOString() ?? null,
          quizScore: p.quizScore,
          attempts: p.attempts,
          notes: p.notes,
          dueAt: dueAt?.toISOString() ?? null,
          overdue,
          material: p.pathItem.material,
          isRequired: p.pathItem.isRequired,
        };
      });
    const required = progress.filter((p) => p.isRequired);
    const done = required.filter((p) => p.status === 'COMPLETED').length;
    return {
      id: a.id,
      personId: a.personId,
      person: a.person
        ? {
            id: a.person.id,
            fullName: a.person.fullName,
            isActive: a.person.isActive,
            store: a.person.store,
          }
        : undefined,
      path: a.path,
      startDate: a.startDate.toISOString(),
      percentDone: required.length === 0 ? 100 : Math.round((done / required.length) * 100),
      overdueCount: progress.filter((p) => p.overdue).length,
      progress,
    };
  }

  private validateMaterialUrl(kind: string, url?: string): void {
    if (!url?.trim()) {
      throw new BadRequestException({
        code: 'INTERNAL_TRAINING_URL_REQUIRED',
        message: 'Tài liệu cần file hoặc đường dẫn.',
      });
    }
    if (kind === 'FILE') {
      // FILE materials live in the PRIVATE store — `url` holds the name.
      assertPrivateFileName(url, 'INTERNAL_TRAINING');
    } else if (!/^https?:\/\//i.test(url)) {
      throw new BadRequestException({
        code: 'INTERNAL_TRAINING_URL_INVALID',
        message: 'Đường dẫn phải là http(s).',
      });
    }
  }

  private async assertMaterialsExist(ids: string[]): Promise<void> {
    const found = await this.prisma.trainingMaterial.count({ where: { id: { in: ids } } });
    if (found !== new Set(ids).size) {
      throw new BadRequestException({
        code: 'INTERNAL_TRAINING_MATERIAL_NOT_FOUND',
        message: 'Có tài liệu không tồn tại.',
      });
    }
  }

  private async materialById(id: string) {
    const material = await this.prisma.trainingMaterial.findUnique({ where: { id } });
    if (!material) {
      this.notFound('INTERNAL_TRAINING_MATERIAL_NOT_FOUND', 'Không tìm thấy tài liệu.');
    }
    return material;
  }

  private badStore(): never {
    throw new BadRequestException({
      code: 'INTERNAL_TRAINING_STORE_NOT_FOUND',
      message: 'Chi nhánh không tồn tại.',
    });
  }

  private notFound(code: string, message: string): never {
    throw new NotFoundException({ code, message });
  }
}
