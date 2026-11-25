import { InjectQueue } from '@nestjs/bullmq';
import { Module, OnModuleInit } from '@nestjs/common';
import { Queue } from 'bullmq';

import { PrismaModule } from '../../common/database/prisma.module';
import { QUEUE_NAMES } from '../../common/queue/queue.constants';
import { QueueModule } from '../../common/queue/queue.module';
import { AdminController } from './controllers/admin.controller';
import { AdminNotificationController } from './controllers/admin-notification.controller';
import { AuditLogController } from './controllers/audit-log.controller';
import { SettingsController } from './controllers/settings.controller';
import { AdminNotificationsGateway } from './gateways/admin-notifications.gateway';
import { AdminRepository } from './repositories/admin.repository';
import { AdminService } from './services/admin.service';
import { AdminNotificationService } from './services/admin-notification.service';
import { AuditLogService } from './services/audit-log.service';
import { SettingsService } from './services/settings.service';
import { DataArchiveWorker } from './workers/data-archive.worker';

@Module({
  imports: [PrismaModule, QueueModule],
  controllers: [
    AdminController,
    AuditLogController,
    SettingsController,
    AdminNotificationController,
  ],
  providers: [
    AdminService,
    AdminRepository,
    AuditLogService,
    SettingsService,
    AdminNotificationsGateway,
    AdminNotificationService,
    DataArchiveWorker,
  ],
  exports: [AdminService, AdminNotificationService],
})
export class AdminModule implements OnModuleInit {
  constructor(@InjectQueue(QUEUE_NAMES.SCHEDULED_JOBS) private readonly scheduledQueue: Queue) {}

  async onModuleInit() {
    await this.scheduledQueue.add(
      'archive-old-bookings',
      {},
      {
        repeat: {
          pattern: '0 0 * * *', // Every day at midnight
        },
      },
    );
  }
}
