import { MiddlewareConsumer, Module, NestModule } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { ScheduleModule } from '@nestjs/schedule';
import { ThrottlerModule } from '@nestjs/throttler';
import { LoggerModule } from 'nestjs-pino';

import { AnalyticsModule } from './analytics/analytics.module';
import { AuthModule } from './auth/auth.module';
import { CategoriesModule } from './categories/categories.module';
import { CollectionsModule } from './collections/collections.module';
import { RequestIdMiddleware } from './common/middleware/request-id.middleware';
import { CouponsModule } from './coupons/coupons.module';
import { HealthModule } from './health/health.module';
import { KitchenModule } from './kitchen/kitchen.module';
import { LoyaltyModule } from './loyalty/loyalty.module';
import { NotificationsModule } from './notifications/notifications.module';
import { OrdersModule } from './orders/orders.module';
import { PaymentsModule } from './payments/payments.module';
import { PrismaModule } from './prisma/prisma.module';
import { ProductsModule } from './products/products.module';
import { RealtimeModule } from './realtime/realtime.module';
import { RefundsModule } from './refunds/refunds.module';
import { ThreadsModule } from './threads/threads.module';
import { UploadsModule } from './uploads/uploads.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true, cache: true }),
    LoggerModule.forRoot({
      pinoHttp: {
        // Pull the id we set in RequestIdMiddleware so log lines for the
        // same request can be grepped/aggregated together.
        genReqId: (req) => (req as { id?: string }).id ?? '',
        transport:
          process.env.NODE_ENV !== 'production'
            ? { target: 'pino-pretty', options: { singleLine: true } }
            : undefined,
        level: process.env.LOG_LEVEL ?? 'info',
        autoLogging: { ignore: (req) => req.url === '/api/v1/health' },
        // Production redactions — never log Authorization / cookies.
        redact: {
          paths: ['req.headers.authorization', 'req.headers.cookie'],
          censor: '[redacted]',
        },
      },
    }),
    ThrottlerModule.forRoot([{ ttl: 60_000, limit: 120 }]),
    ScheduleModule.forRoot(),
    PrismaModule,
    AuthModule,
    HealthModule,
    CategoriesModule,
    CollectionsModule,
    ThreadsModule,
    ProductsModule,
    UploadsModule,
    RealtimeModule,
    PaymentsModule,
    RefundsModule,
    LoyaltyModule,
    CouponsModule,
    NotificationsModule,
    OrdersModule,
    KitchenModule,
    AnalyticsModule,
  ],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer): void {
    consumer.apply(RequestIdMiddleware).forRoutes('*');
  }
}
