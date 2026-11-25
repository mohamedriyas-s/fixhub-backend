import { Module } from '@nestjs/common';

import { RedisModule } from '../../common/redis/redis.module';
import { StorageModule } from '../../common/storage/storage.module';
import { AdminModule } from '../admin/admin.module';
import { BookingModule } from '../booking/booking.module';
import { TrackingModule } from '../tracking/tracking.module';
import { TechnicianController } from './controllers/technician.controller';
import { JobOfferRepository } from './repositories/job-offer.repository';
import { TechnicianRepository } from './repositories/technician.repository';
import { TechnicianDocumentRepository } from './repositories/technician-document.repository';
import { TechnicianEarningsRepository } from './repositories/technician-earnings.repository';
import { TechnicianJobRepository } from './repositories/technician-job.repository';
import { TechnicianReviewRepository } from './repositories/technician-review.repository';
import { TechnicianServiceAreaRepository } from './repositories/technician-service-area.repository';
import { TechnicianSpecializationRepository } from './repositories/technician-specialization.repository';
import { JobOfferService } from './services/job-offer.service';
import { TechnicianService } from './services/technician.service';
import { TechnicianDocumentService } from './services/technician-document.service';
import { TechnicianEarningsService } from './services/technician-earnings.service';
import { TechnicianHeartbeatService } from './services/technician-heartbeat.service';
import { TechnicianJobService } from './services/technician-job.service';
import { TechnicianReviewService } from './services/technician-review.service';
import { TechnicianServiceAreaService } from './services/technician-service-area.service';
import { TechnicianSpecializationService } from './services/technician-specialization.service';

@Module({
  imports: [StorageModule, BookingModule, TrackingModule, AdminModule, RedisModule],
  controllers: [TechnicianController],
  providers: [
    // Services
    TechnicianService,
    TechnicianDocumentService,
    TechnicianSpecializationService,
    TechnicianServiceAreaService,
    TechnicianJobService,
    TechnicianReviewService,
    TechnicianEarningsService,
    JobOfferService,
    TechnicianHeartbeatService,
    // Repositories
    TechnicianRepository,
    TechnicianDocumentRepository,
    TechnicianSpecializationRepository,
    TechnicianServiceAreaRepository,
    TechnicianJobRepository,
    TechnicianReviewRepository,
    TechnicianEarningsRepository,
    JobOfferRepository,
  ],
  exports: [TechnicianService, TechnicianHeartbeatService],
})
export class TechnicianModule {}
