import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { EventEmitter2 } from '@nestjs/event-emitter';

import { PrismaService } from '../../../common/database/prisma.service';
import { RedisService } from '../../../common/redis/redis.service';

const HEARTBEAT_PREFIX = 'technician:heartbeat:';
const HEARTBEAT_TTL_SECONDS = 300; // 5 minutes

@Injectable()
export class TechnicianHeartbeatService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(TechnicianHeartbeatService.name);
  private subscriberClient: any;

  constructor(
    private readonly redisService: RedisService,
    private readonly prisma: PrismaService,
    private readonly eventEmitter: EventEmitter2,
  ) {}

  async onModuleInit() {
    this.subscriberClient = this.redisService.getClient().duplicate();
    await this.subscriberClient.subscribe('__keyevent@0__:expired');

    this.subscriberClient.on('message', async (channel: string, message: string) => {
      if (channel === '__keyevent@0__:expired' && message.startsWith(HEARTBEAT_PREFIX)) {
        const technicianId = message.replace(HEARTBEAT_PREFIX, '');
        this.logger.warn(`Heartbeat expired for technician: ${technicianId}. Marking unavailable.`);
        await this.handleExpiredHeartbeat(technicianId);
      }
    });
  }

  async onModuleDestroy() {
    if (this.subscriberClient) {
      await this.subscriberClient.quit();
    }
  }

  async ping(technicianId: string) {
    const key = `${HEARTBEAT_PREFIX}${technicianId}`;
    await this.redisService.set(key, 'active', HEARTBEAT_TTL_SECONDS);
  }

  private async handleExpiredHeartbeat(technicianId: string) {
    try {
      const technician = await this.prisma.technician.update({
        where: { id: technicianId },
        data: { isAvailable: false },
      });
      this.eventEmitter.emit('technician.availability_changed', technicianId);
    } catch (error) {
      this.logger.error(`Failed to mark technician ${technicianId} unavailable`, error);
    }
  }
}
