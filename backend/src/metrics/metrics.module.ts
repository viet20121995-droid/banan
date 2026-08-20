import { Module } from '@nestjs/common';

import { NotificationsModule } from '../notifications/notifications.module';

import { MetricsController } from './metrics.controller';
import { MetricsService } from './metrics.service';

@Module({
  imports: [NotificationsModule],
  controllers: [MetricsController],
  providers: [MetricsService],
})
export class MetricsModule {}
