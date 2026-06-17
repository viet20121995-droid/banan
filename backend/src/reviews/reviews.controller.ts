import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { ReviewStatus, Role } from '@prisma/client';

import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { Public } from '../auth/decorators/public.decorator';
import { Roles } from '../auth/decorators/roles.decorator';
import type { AuthPrincipal } from '../auth/types/jwt-payload';
import { merchantStoreScope } from '../common/merchant-scope';

import { CreateReviewDto } from './dto/create-review.dto';
import { ListReviewsDto } from './dto/list-reviews.dto';
import { ModerateReviewDto } from './dto/moderate-review.dto';
import { ReviewsService } from './reviews.service';

@ApiTags('reviews')
@Controller({ path: 'reviews', version: '1' })
export class ReviewsController {
  constructor(private readonly reviews: ReviewsService) {}

  /// Public — anyone can read published reviews for a product.
  @Public()
  @Get('product/:productId')
  findForProduct(
    @Param('productId') productId: string,
    @Query('page') page?: string,
    @Query('perPage') perPage?: string,
  ) {
    return this.reviews.findPublicForProduct(
      productId,
      Number(page) || 1,
      Number(perPage) || 20,
    );
  }

  /// Authenticated — list MY reviews.
  @Roles(Role.CUSTOMER)
  @Get('mine')
  findMine(
    @CurrentUser() user: AuthPrincipal,
    @Query('page') page?: string,
    @Query('perPage') perPage?: string,
  ) {
    return this.reviews.findMine(
      user.sub,
      Number(page) || 1,
      Number(perPage) || 20,
    );
  }

  /// Authenticated — list my reviews against a specific order (drives the
  /// per-item "Đánh giá / Sửa đánh giá" CTA on the customer order detail).
  @Roles(Role.CUSTOMER)
  @Get('mine/order/:orderId')
  findByOrder(
    @CurrentUser() user: AuthPrincipal,
    @Param('orderId') orderId: string,
  ) {
    return this.reviews.findByUserAndOrder(user.sub, orderId);
  }

  @Roles(Role.CUSTOMER)
  @Post()
  create(@CurrentUser() user: AuthPrincipal, @Body() dto: CreateReviewDto) {
    return this.reviews.create(user.sub, dto);
  }

  @Roles(Role.CUSTOMER)
  @HttpCode(HttpStatus.NO_CONTENT)
  @Delete(':id')
  remove(@CurrentUser() user: AuthPrincipal, @Param('id') id: string) {
    return this.reviews.remove(user.sub, id);
  }
}

@ApiBearerAuth()
@ApiTags('merchant.reviews')
@Controller({ path: 'merchant/reviews', version: '1' })
@Roles(Role.MERCHANT_OWNER, Role.MERCHANT_STAFF, Role.ADMIN)
export class MerchantReviewsController {
  constructor(private readonly reviews: ReviewsService) {}

  @Get()
  findAll(
    @CurrentUser() user: AuthPrincipal,
    @Query() q: ListReviewsDto,
    @Query('status') status?: ReviewStatus,
  ) {
    return this.reviews.findAllForMerchant(
      { ...q, status },
      merchantStoreScope(user),
    );
  }

  @Patch(':id/moderate')
  moderate(
    @CurrentUser() user: AuthPrincipal,
    @Param('id') id: string,
    @Body() dto: ModerateReviewDto,
  ) {
    return this.reviews.moderate(id, dto, user.sub, merchantStoreScope(user));
  }
}
