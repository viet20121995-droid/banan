import {
  Body,
  Controller,
  HttpCode,
  HttpStatus,
  Post,
} from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';

import { Public } from '../auth/decorators/public.decorator';

import { ContactService } from './contact.service';
import { ContactDto } from './dto/contact.dto';

@ApiTags('contact')
@Controller({ path: 'contact', version: '1' })
export class ContactController {
  constructor(private readonly contact: ContactService) {}

  /** Public support contact form. Rate-limited by the global throttler. */
  @Public()
  @Post()
  @HttpCode(HttpStatus.OK)
  async submit(@Body() dto: ContactDto) {
    await this.contact.submit(dto);
    return { ok: true };
  }
}
