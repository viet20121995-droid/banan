import { Module } from '@nestjs/common';

import { NotificationsModule } from '../notifications/notifications.module';

import { ManufacturingController } from './manufacturing.controller';
import { ManufacturingSchedulerService } from './manufacturing-scheduler.service';
import { ManufacturingService } from './manufacturing.service';

@Module({
  imports: [NotificationsModule],
  controllers: [ManufacturingController],
  providers: [ManufacturingService, ManufacturingSchedulerService],
  exports: [ManufacturingService],
})
export class ManufacturingModule {}
