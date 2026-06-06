import { MiddlewareConsumer, Module, NestModule } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { APP_INTERCEPTOR } from '@nestjs/core';
import { ScheduleModule } from '@nestjs/schedule';
import { ThrottlerModule } from '@nestjs/throttler';
import { LoggerModule } from 'nestjs-pino';

import { CatalogBroadcastInterceptor } from './common/interceptors/catalog-broadcast.interceptor';

import { AddressesModule } from './addresses/addresses.module';
import { AdminModule } from './admin/admin.module';
import { AnalyticsModule } from './analytics/analytics.module';
import { AuthModule } from './auth/auth.module';
import { BannersModule } from './banners/banners.module';
import { BundlesModule } from './bundles/bundles.module';
import { CategoriesModule } from './categories/categories.module';
import { CollectionsModule } from './collections/collections.module';
import { ContactModule } from './contact/contact.module';
import { RequestIdMiddleware } from './common/middleware/request-id.middleware';
import { CouponsModule } from './coupons/coupons.module';
import { PromotionsModule } from './promotions/promotions.module';
import { CustomersModule } from './customers/customers.module';
import { DisplayConfigModule } from './display-config/display-config.module';
import { GeoModule } from './geo/geo.module';
import { GiftCardsModule } from './gift-cards/gift-cards.module';
import { HealthModule } from './health/health.module';
import { KitchenModule } from './kitchen/kitchen.module';
import { LoyaltyModule } from './loyalty/loyalty.module';
import { MarketingModule } from './marketing/marketing.module';
import { NewsletterModule } from './newsletter/newsletter.module';
import { NotificationsModule } from './notifications/notifications.module';
import { OrdersModule } from './orders/orders.module';
import { PaymentsModule } from './payments/payments.module';
import { PrismaModule } from './prisma/prisma.module';
import { ProductsModule } from './products/products.module';
import { PromoPopupModule } from './promo-popup/promo-popup.module';
import { RealtimeModule } from './realtime/realtime.module';
import { RefundsModule } from './refunds/refunds.module';
import { ReportsModule } from './reports/reports.module';
import { ReviewsModule } from './reviews/reviews.module';
import { SiteContentModule } from './site-content/site-content.module';
import { StoresModule } from './stores/stores.module';
import { ThreadsModule } from './threads/threads.module';
import { UploadsModule } from './uploads/uploads.module';
import { WishlistModule } from './wishlist/wishlist.module';

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
    AddressesModule,
    AdminModule,
    BannersModule,
    BundlesModule,
    CustomersModule,
    DisplayConfigModule,
    GeoModule,
    GiftCardsModule,
    HealthModule,
    CategoriesModule,
    CollectionsModule,
    ContactModule,
    StoresModule,
    ThreadsModule,
    ProductsModule,
    PromoPopupModule,
    UploadsModule,
    RealtimeModule,
    PaymentsModule,
    RefundsModule,
    LoyaltyModule,
    CouponsModule,
    PromotionsModule,
    MarketingModule,
    NewsletterModule,
    NotificationsModule,
    OrdersModule,
    KitchenModule,
    AnalyticsModule,
    ReviewsModule,
    ReportsModule,
    WishlistModule,
    SiteContentModule,
  ],
  providers: [
    // Realtime catalog sync — broadcasts catalog/config changes to clients.
    { provide: APP_INTERCEPTOR, useClass: CatalogBroadcastInterceptor },
  ],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer): void {
    consumer.apply(RequestIdMiddleware).forRoutes('*');
  }
}
