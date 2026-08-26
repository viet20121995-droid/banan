import { Module } from '@nestjs/common';

import { NotificationsModule } from '../notifications/notifications.module';

import { InternalFilesCleanupService } from './files/internal-files-cleanup.service';
import { InternalFilesController } from './files/internal-files.controller';
import { InternalReportDeliveryService } from './internal-report-delivery.service';
import { MsPublicController } from './ms/ms-public.controller';
import { MsController } from './ms/ms.controller';
import { MsService } from './ms/ms.service';
import { InternalPdfService } from './pdf/internal-pdf.service';
import { QcController } from './qc/qc.controller';
import { QcService } from './qc/qc.service';
import { ScheduleController } from './schedule/schedule.controller';
import { ScheduleService } from './schedule/schedule.service';
import { TrainingController } from './training/training.controller';
import { TrainingService } from './training/training.service';

/**
 * Internal ops app (internal.banancakes.vn): QC, Mystery Shopper, Training,
 * weekly schedule. Every controller here is @Roles(ADMIN) except the
 * token-gated MsPublicController.
 */
@Module({
  imports: [NotificationsModule],
  controllers: [
    QcController,
    MsController,
    MsPublicController,
    TrainingController,
    ScheduleController,
    InternalFilesController,
  ],
  providers: [
    QcService,
    MsService,
    TrainingService,
    ScheduleService,
    InternalPdfService,
    InternalReportDeliveryService,
    InternalFilesCleanupService,
  ],
})
export class InternalModule {}
