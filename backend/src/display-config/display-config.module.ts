import { Module } from '@nestjs/common';

import { DisplayConfigController } from './display-config.controller';
import { DisplayConfigService } from './display-config.service';

@Module({
  controllers: [DisplayConfigController],
  providers: [DisplayConfigService],
  exports: [DisplayConfigService],
})
export class DisplayConfigModule {}
