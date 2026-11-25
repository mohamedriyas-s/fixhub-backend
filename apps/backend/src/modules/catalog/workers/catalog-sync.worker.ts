import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Injectable, Logger } from '@nestjs/common';
import { Job } from 'bullmq';

import { PrismaService } from '../../../common/database/prisma.service';
import { QUEUE_NAMES } from '../../../common/queue/queue.constants';

@Processor(QUEUE_NAMES.SCHEDULED_JOBS)
@Injectable()
export class CatalogSyncWorker extends WorkerHost {
  private readonly logger = new Logger(CatalogSyncWorker.name);

  constructor(private readonly prisma: PrismaService) {
    super();
  }

  async process(job: Job<any, any, string>): Promise<any> {
    if (job.name === 'sync-catalog-availability') {
      const { technicianId } = job.data;
      this.logger.debug(`Processing catalog sync for technician ${technicianId}`);
      await this.syncTechnicianAvailability(technicianId);
    }
  }

  private async syncTechnicianAvailability(technicianId: string) {
    const technician = await this.prisma.technician.findUnique({
      where: { id: technicianId },
      include: {
        specializations: true,
        serviceAreas: true,
      },
    });

    if (!technician) return;

    const subServiceIds = technician.specializations.map((s) => s.subServiceId);
    const serviceAreaIds = technician.serviceAreas.map((a) => a.serviceAreaId);

    if (subServiceIds.length === 0 || serviceAreaIds.length === 0) {
      return;
    }

    const subServiceAreas = await this.prisma.subServiceArea.findMany({
      where: {
        subServiceId: { in: subServiceIds },
        serviceAreaId: { in: serviceAreaIds },
      },
    });

    for (const ssa of subServiceAreas) {
      const activeTechCount = await this.prisma.technician.count({
        where: {
          isAvailable: true,
          verificationStatus: 'VERIFIED',
          deletedAt: null,
          user: { isActive: true, deletedAt: null },
          serviceAreas: {
            some: { serviceAreaId: ssa.serviceAreaId },
          },
          specializations: {
            some: { subServiceId: ssa.subServiceId },
          },
        },
      });

      const shouldBeActive = activeTechCount > 0;

      if (ssa.systemActive !== shouldBeActive) {
        await this.prisma.subServiceArea.update({
          where: { id: ssa.id },
          data: { systemActive: shouldBeActive },
        });
        this.logger.debug(`Updated SubServiceArea ${ssa.id} systemActive to ${shouldBeActive}`);
      }
    }
  }
}
