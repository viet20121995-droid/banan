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
import { SurveyPublicController } from './survey/survey-public.controller';
import { SurveyController } from './survey/survey.controller';
import { SurveyService } from './survey/survey.service';
import { TraineeTrainingController } from './training/trainee-training.controller';
import { TrainingController } from './training/training.controller';
import { TrainingService } from './training/training.service';

/**
 * Internal ops app (internal.banancakes.vn): QC, Mystery Shopper, Training,
 * weekly schedule, dine-in Survey. Management controllers are @Roles(ADMIN);
 * the trainee surface (TraineeTrainingController + training-file reads) also
 * admits TRAINEE; MsPublicController is token/access-code gated and
 * SurveyPublicController is fully public (throttled), no account.
 */
@Module({
  imports: [NotificationsModule],
  controllers: [
    QcController,
    MsController,
    MsPublicController,
    TrainingController,
    TraineeTrainingController,
    ScheduleController,
    SurveyController,
    SurveyPublicController,
    InternalFilesController,
  ],
  providers: [
    QcService,
    MsService,
    TrainingService,
    ScheduleService,
    SurveyService,
    InternalPdfService,
    InternalReportDeliveryService,
    InternalFilesCleanupService,
  ],
})
export class InternalModule {}
