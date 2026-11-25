import { Module } from '@nestjs/common';

import { PrismaModule } from '../../common/database/prisma.module';
import { RedisModule } from '../../common/redis/redis.module';
import { AdminModule } from '../admin/admin.module';
import { AdminServiceAreaController } from './controllers/admin-service-area.controller';
import { ServiceAreaController } from './controllers/service-area.controller';
import { ServiceAreaRepository } from './repositories/service-area.repository';
import { ServiceAreaService } from './services/service-area.service';
import { ServiceAreaCacheService } from './services/service-area-cache.service';

@Module({
  imports: [PrismaModule, RedisModule, AdminModule],
  controllers: [ServiceAreaController, AdminServiceAreaController],
  providers: [ServiceAreaService, ServiceAreaRepository, ServiceAreaCacheService],
  exports: [ServiceAreaService],
})
export class ServiceAreaModule {}
