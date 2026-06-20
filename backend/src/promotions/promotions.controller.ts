import { Body, Controller, Delete, Get, Param, Patch, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Role } from '@prisma/client';

import { Roles } from '../auth/decorators/roles.decorator';

import { CreateCampaignDto, UpdateCampaignDto } from './dto';
import { PromotionsService } from './promotions.service';

@ApiBearerAuth()
@ApiTags('campaigns')
@Controller({ path: 'merchant/campaigns', version: '1' })
@Roles(Role.ADMIN)
export class CampaignsController {
  constructor(private readonly promotions: PromotionsService) {}

  @Get()
  list(@Query('type') type?: string) {
    return this.promotions.list(type);
  }

  @Get(':id')
  get(@Param('id') id: string) {
    return this.promotions.get(id);
  }

  @Post()
  create(@Body() dto: CreateCampaignDto) {
    return this.promotions.create(dto);
  }

  @Patch(':id')
  update(@Param('id') id: string, @Body() dto: UpdateCampaignDto) {
    return this.promotions.update(id, dto);
  }

  @Delete(':id')
  remove(@Param('id') id: string) {
    return this.promotions.remove(id);
  }
}
