import { Module } from '@nestjs/common';

import { RealtimeModule } from '../realtime/realtime.module';

import { MerchantReviewsController, ReviewsController } from './reviews.controller';
import { ReviewsService } from './reviews.service';

@Module({
  imports: [RealtimeModule],
  controllers: [ReviewsController, MerchantReviewsController],
  providers: [ReviewsService],
  exports: [ReviewsService],
})
export class ReviewsModule {}
