import { Module } from '@nestjs/common';

import { RealtimeModule } from '../realtime/realtime.module';

import { BroadcastController } from './broadcast.controller';
import { MeDevicesController } from './devices.controller';
import { EmailService } from './email.service';
import { NotificationsController } from './notifications.controller';
import { NotificationsService } from './notifications.service';
import { PushService } from './push.service';

@Module({
  imports: [RealtimeModule],
  controllers: [NotificationsController, MeDevicesController, BroadcastController],
  providers: [NotificationsService, EmailService, PushService],
  exports: [NotificationsService, EmailService],
})
export class NotificationsModule {}
