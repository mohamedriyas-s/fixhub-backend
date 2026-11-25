import { Module } from '@nestjs/common';

import { PrismaModule } from '../../common/database/prisma.module';
import { QueueModule } from '../../common/queue/queue.module';
import { RedisModule } from '../../common/redis/redis.module';
import { AdminCatalogController } from './controllers/admin-catalog.controller';
import { CatalogController } from './controllers/catalog.controller';
import { CatalogRepository } from './repositories/catalog.repository';
import { CatalogService } from './services/catalog.service';
import { CatalogCacheService } from './services/catalog-cache.service';
import { CatalogSyncService } from './services/catalog-sync.service';
import { CatalogSyncWorker } from './workers/catalog-sync.worker';

@Module({
  imports: [PrismaModule, RedisModule, QueueModule],
  controllers: [CatalogController, AdminCatalogController],
  providers: [
    CatalogService,
    CatalogRepository,
    CatalogCacheService,
    CatalogSyncService,
    CatalogSyncWorker,
  ],
  exports: [CatalogService],
})
export class CatalogModule {}
