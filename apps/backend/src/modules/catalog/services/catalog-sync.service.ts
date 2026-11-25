import { InjectQueue } from '@nestjs/bullmq';
import { Injectable, Logger } from '@nestjs/common';
import { OnEvent } from '@nestjs/event-emitter';
import { Queue } from 'bullmq';

import { QUEUE_NAMES } from '../../../common/queue/queue.constants';

@Injectable()
export class CatalogSyncService {
  private readonly logger = new Logger(CatalogSyncService.name);

  constructor(@InjectQueue(QUEUE_NAMES.SCHEDULED_JOBS) private readonly syncQueue: Queue) {}

  @OnEvent('technician.availability_changed')
  async handleTechnicianAvailability(technicianId: string) {
    this.logger.log(`Queueing catalog sync for technician ${technicianId}...`);
    await this.syncQueue.add(
      'sync-catalog-availability',
      { technicianId },
      {
        removeOnComplete: true,
        removeOnFail: false,
      },
    );
  }

  @OnEvent('technician.verified')
  async handleTechnicianVerified(technicianId: string) {
    this.logger.log(`Queueing catalog sync for verified technician ${technicianId}...`);
    await this.syncQueue.add(
      'sync-catalog-availability',
      { technicianId },
      {
        removeOnComplete: true,
      },
    );
  }
}
