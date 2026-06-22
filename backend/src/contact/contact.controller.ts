import { Body, Controller, HttpCode, HttpStatus, Post } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';

import { Public } from '../auth/decorators/public.decorator';

import { ContactService } from './contact.service';
import { ContactDto } from './dto/contact.dto';

@ApiTags('contact')
@Controller({ path: 'contact', version: '1' })
export class ContactController {
  constructor(private readonly contact: ContactService) {}

  /** Public support contact form. Tightly rate-limited (spam / abuse / DB
   *  bloat from a public free-text endpoint). */
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  @Public()
  @Post()
  @HttpCode(HttpStatus.OK)
  async submit(@Body() dto: ContactDto) {
    await this.contact.submit(dto);
    return { ok: true };
  }
}
