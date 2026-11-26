import { Module } from '@nestjs/common';

import { PrismaModule } from '../../common/database/prisma.module';
import { RedisModule } from '../../common/redis/redis.module';
import { StorageModule } from '../../common/storage/storage.module';
import { AdminModule } from '../admin/admin.module';
import { NotificationModule } from '../notification/notification.module';
import { JobOfferRepository } from '../technician/repositories/job-offer.repository';
import { TrackingModule } from '../tracking/tracking.module';
import { AdminBookingController } from './controllers/admin-booking.controller';
import { BookingController } from './controllers/booking.controller';
import { BookingStateMachineService } from './lifecycle/booking-state-machine.service';
import { BookingRepository } from './repositories/booking.repository';
import { BookingMediaRepository } from './repositories/booking-media.repository';
import { BookingService } from './services/booking.service';
import { BookingDispatchService } from './services/booking-dispatch.service';
import { BookingLifecycleService } from './services/booking-lifecycle.service';
import { BookingLockService } from './services/booking-lock.service';
import { BookingMediaService } from './services/booking-media.service';
import { BookingQueryService } from './services/booking-query.service';
import { BookingQueryCacheService } from './services/booking-query-cache.service';

@Module({
  imports: [
    PrismaModule,
    RedisModule,
    StorageModule,
    NotificationModule,
    TrackingModule,
    AdminModule,
  ],
  controllers: [BookingController, AdminBookingController],
  providers: [
    BookingService,
    BookingDispatchService,
    BookingMediaService,
    BookingQueryService,
    BookingQueryCacheService,
    BookingLifecycleService,
    BookingStateMachineService,
    BookingRepository,
    BookingMediaRepository,
    BookingLockService,
    // JobOfferRepository is registered here (not via TechnicianModule) to avoid
    // a circular dependency: TechnicianModule → BookingModule → TechnicianModule
    JobOfferRepository,
  ],
  exports: [BookingService, BookingLifecycleService, BookingDispatchService, BookingQueryCacheService],
})
export class BookingModule {}
