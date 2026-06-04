import { Module } from '@nestjs/common';

import { NotificationsModule } from '../notifications/notifications.module';

import {
  MerchantNewsletterController,
  NewsletterController,
} from './newsletter.controller';
import { NewsletterService } from './newsletter.service';

@Module({
  imports: [NotificationsModule],
  controllers: [NewsletterController, MerchantNewsletterController],
  providers: [NewsletterService],
})
export class NewsletterModule {}
