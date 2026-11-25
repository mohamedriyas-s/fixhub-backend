import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Injectable, Logger } from '@nestjs/common';
import { Job } from 'bullmq';

import { PrismaService } from '../../../common/database/prisma.service';
import { QUEUE_NAMES } from '../../../common/queue/queue.constants';

@Processor(QUEUE_NAMES.SCHEDULED_JOBS)
@Injectable()
export class DataArchiveWorker extends WorkerHost {
  private readonly logger = new Logger(DataArchiveWorker.name);

  constructor(private readonly prisma: PrismaService) {
    super();
  }

  async process(job: Job<any, any, string>): Promise<any> {
    if (job.name === 'archive-old-bookings') {
      this.logger.log('Running daily data archive worker...');
      await this.archiveOldBookings();
    }
  }

  private async archiveOldBookings() {
    const ninetyDaysAgo = new Date();
    ninetyDaysAgo.setDate(ninetyDaysAgo.getDate() - 90);

    const oldBookings = await this.prisma.booking.findMany({
      where: {
        status: { in: ['COMPLETED', 'CANCELLED', 'FAILED'] },
        updatedAt: { lt: ninetyDaysAgo },
      },
      include: {
        timeline: true,
        payment: true,
        jobOffers: true,
        review: true,
      },
      take: 100, // Process in batches
    });

    if (oldBookings.length === 0) {
      this.logger.debug('No bookings to archive.');
      return;
    }

    this.logger.log(`Found ${oldBookings.length} bookings to archive. Processing...`);

    for (const booking of oldBookings) {
      await this.prisma.$transaction(async (tx) => {
        // Create archived record
        await tx.archivedBooking.create({
          data: {
            id: booking.id,
            bookingNumber: booking.bookingNumber,
            customerId: booking.customerId,
            technicianId: booking.technicianId,
            subServiceId: booking.subServiceId,
            addressId: booking.addressId,
            status: booking.status,
            scheduledDate: booking.scheduledDate,
            scheduledSlot: booking.scheduledSlot,
            description: booking.description,
            totalAmount: booking.totalAmount,
            notes: booking.notes,
            revisedAmount: booking.revisedAmount,
            priceRevisionNote: booking.priceRevisionNote,
            customerConsentAt: booking.customerConsentAt,
            completedAt: booking.completedAt,
            cancelledAt: booking.cancelledAt,
            cancelledBy: booking.cancelledBy,
            cancelReason: booking.cancelReason,
            failedAt: booking.failedAt,
            failureReason: booking.failureReason,
            originalCreatedAt: booking.createdAt,
            originalUpdatedAt: booking.updatedAt,
            payload: {
              timeline: booking.timeline,
              payment: booking.payment,
              jobOffers: booking.jobOffers,
              review: booking.review,
            } as any,
          },
        });

        // Delete relations to maintain referential integrity before deleting main booking
        await tx.bookingTimeline.deleteMany({ where: { bookingId: booking.id } });
        await tx.payment.deleteMany({ where: { bookingId: booking.id } });
        await tx.jobOffer.deleteMany({ where: { bookingId: booking.id } });
        await tx.review.deleteMany({ where: { bookingId: booking.id } });

        // Delete the original booking
        await tx.booking.delete({ where: { id: booking.id } });
      });
    }

    this.logger.log(`Successfully archived ${oldBookings.length} bookings.`);
  }
}
