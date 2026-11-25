import { Module } from '@nestjs/common';

import { QueueModule } from '../../common/queue/queue.module';
import { RedisModule } from '../../common/redis/redis.module';
import { TrackingModule } from '../tracking/tracking.module';
import { NotificationController } from './controllers/notification.controller';
import {
  EmailNotificationProcessor,
  PushNotificationProcessor,
  SmsNotificationProcessor,
} from './processors/notification.processor';
import { NotificationRepository } from './repositories/notification.repository';
import { NotificationService } from './services/notification.service';
import {
  EmailNotificationChannel,
  PushNotificationChannel,
  SmsNotificationChannel,
} from './services/notification-channel.service';

@Module({
  imports: [QueueModule, RedisModule, TrackingModule],
  controllers: [NotificationController],
  providers: [
    NotificationService,
    NotificationRepository,
    PushNotificationChannel,
    SmsNotificationChannel,
    EmailNotificationChannel,
    PushNotificationProcessor,
    SmsNotificationProcessor,
    EmailNotificationProcessor,
  ],
  exports: [NotificationService],
})
export class NotificationModule {}
