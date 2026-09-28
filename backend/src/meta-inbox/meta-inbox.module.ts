import { Module } from '@nestjs/common';

import { NotificationsModule } from '../notifications/notifications.module';

import { GrokClient } from './grok.client';
import { MetaGraphClient } from './meta-graph.client';
import { MetaInboxKnowledge } from './meta-inbox.knowledge';
import { MetaInboxService } from './meta-inbox.service';
import { MetaWebhookController } from './meta-webhook.controller';

@Module({
  imports: [NotificationsModule],
  controllers: [MetaWebhookController],
  providers: [GrokClient, MetaGraphClient, MetaInboxKnowledge, MetaInboxService],
})
export class MetaInboxModule {}
