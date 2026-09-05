import { Module } from '@nestjs/common';
import { APP_FILTER, APP_INTERCEPTOR } from '@nestjs/core';

import { AllExceptionsFilter } from '../common/filters/all-exceptions.filter';
import { NotificationsModule } from '../notifications/notifications.module';

import { AuditLogController } from './audit-log.controller';
import { AuditLogInterceptor } from './audit-log.interceptor';
import { AuditLogService } from './audit-log.service';
import { OpsAlertService } from './ops-alert.service';

/**
 * Running the system: the staff action trail, and the "something broke"
 * mail. Registers the global exception filter here (instead of
 * `useGlobalFilters` in main.ts) so it can be injected with the alert
 * service.
 */
@Module({
  imports: [NotificationsModule],
  controllers: [AuditLogController],
  providers: [
    OpsAlertService,
    AuditLogService,
    { provide: APP_FILTER, useClass: AllExceptionsFilter },
    { provide: APP_INTERCEPTOR, useClass: AuditLogInterceptor },
  ],
  exports: [OpsAlertService],
})
export class OpsModule {}
