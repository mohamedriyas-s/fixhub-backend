import { Injectable, Logger } from '@nestjs/common';
import { BookingStatus, NotificationType, VerificationStatus } from '@prisma/client';

import { PrismaService } from '../../../common/database/prisma.service';
import { NotificationService } from '../../notification/services/notification.service';
import { JobOfferRepository } from '../../technician/repositories/job-offer.repository';

@Injectable()
export class BookingDispatchService {
  private readonly logger = new Logger(BookingDispatchService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly jobOfferRepository: JobOfferRepository,
    private readonly notificationService: NotificationService,
  ) {}

  /**
   * Find eligible technicians for the booking and automatically assign the best match.
   * Direct mandatory assignment (no accept/reject choice).
   * Called after payment is captured (or instant confirmation).
   *
   * Eligibility criteria:
   *  - verificationStatus = VERIFIED
   *  - isAvailable = true
   *  - has a TechnicianServiceArea matching the booking's address pincode
   *  - has a TechnicianSpecialization matching the booking's subServiceId
   *  - has no conflicting job on that scheduledDate & scheduledSlot
   */
  async dispatch(bookingId: string): Promise<void> {
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      include: {
        address: true,
        subService: true,
        customer: { include: { user: true } },
      },
    });

    if (!booking) {
      this.logger.warn(`Dispatch called for non-existent booking ${bookingId}`);
      return;
    }

    if (
      booking.status !== BookingStatus.CONFIRMED &&
      booking.status !== BookingStatus.PENDING_PAYMENT
    ) {
      this.logger.warn(
        `Dispatch skipped for booking ${bookingId} — status is ${booking.status}, expected CONFIRMED or PENDING_PAYMENT`,
      );
      return;
    }

    if (booking.technicianId) {
      this.logger.log(
        `Booking ${booking.bookingNumber} is already assigned to technician ${booking.technicianId}`,
      );
      return;
    }

    const eligibleTechnicians = await this.findEligibleTechniciansForSlot(
      booking.address.pincode,
      booking.subServiceId,
      booking.scheduledDate,
      booking.scheduledSlot,
    );

    if (eligibleTechnicians.length === 0) {
      this.logger.warn(
        `No eligible technicians found for booking ${bookingId} (pincode: ${booking.address.pincode}, subService: ${booking.subServiceId}, slot: ${booking.scheduledSlot})`,
      );
      await this.alertAdminNoTechnicians(booking);
      return;
    }

    // Rank candidates:
    // 1. Fewest jobs on scheduledDate (active + completed)
    // 2. Fewest jobs in the last 7 days
    // 3. Longest time since last assignment (never-assigned first)
    // 4. Highest rating
    const workloadStatuses: BookingStatus[] = [
      BookingStatus.ASSIGNED,
      BookingStatus.ACCEPTED,
      BookingStatus.EN_ROUTE,
      BookingStatus.ARRIVED,
      BookingStatus.IN_PROGRESS,
      BookingStatus.COMPLETED,
    ];
    const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);

    const scoredTechs = await Promise.all(
      eligibleTechnicians.map(async (tech) => {
        const [dailyJobsCount, weeklyJobsCount, lastAssignment] = await Promise.all([
          this.prisma.booking.count({
            where: {
              technicianId: tech.id,
              scheduledDate: booking.scheduledDate,
              status: { in: workloadStatuses },
            },
          }),
          this.prisma.booking.count({
            where: {
              technicianId: tech.id,
              createdAt: { gte: sevenDaysAgo },
              status: { in: workloadStatuses },
            },
          }),
          this.prisma.booking.findFirst({
            where: {
              technicianId: tech.id,
              status: { in: workloadStatuses },
            },
            orderBy: { createdAt: 'desc' },
            select: { createdAt: true },
          }),
        ]);
        return {
          tech,
          dailyJobsCount,
          weeklyJobsCount,
          lastAssignedAtMs: lastAssignment?.createdAt?.getTime() ?? 0,
          rating: Number(tech.rating ?? 0),
        };
      }),
    );

    scoredTechs.sort((a, b) => {
      if (a.dailyJobsCount !== b.dailyJobsCount) {
        return a.dailyJobsCount - b.dailyJobsCount;
      }
      if (a.weeklyJobsCount !== b.weeklyJobsCount) {
        return a.weeklyJobsCount - b.weeklyJobsCount;
      }
      if (a.lastAssignedAtMs !== b.lastAssignedAtMs) {
        return a.lastAssignedAtMs - b.lastAssignedAtMs;
      }
      return b.rating - a.rating;
    });

    const selected = scoredTechs[0].tech;

    this.logger.log(
      `Auto-assigning booking ${booking.bookingNumber} directly to technician ${selected.id} (${selected.user?.name ?? 'Unknown'})`,
    );

    // Direct atomic assignment
    await this.prisma.$transaction(async (tx) => {
      await tx.booking.update({
        where: { id: booking.id },
        data: {
          technicianId: selected.id,
          status: BookingStatus.ASSIGNED,
        },
      });

      await tx.bookingTimeline.create({
        data: {
          bookingId: booking.id,
          status: BookingStatus.ASSIGNED,
          changedByUserId: selected.userId,
          note: `Automated assignment by system to technician ${selected.user?.name ?? selected.id}`,
        },
      });
    });

    const scheduledDateStr = booking.scheduledDate.toISOString().slice(0, 10);

    // Push notification to Technician (Full Job Details)
    if (selected.user?.id) {
      await this.notificationService
        .sendPushNotification({
          userId: selected.user.id,
          title: '🔧 New Job Assigned',
          body: `Booking #${booking.bookingNumber} for ${booking.subService.name} on ${scheduledDateStr} (${booking.scheduledSlot}) has been assigned to you. Address: ${booking.address.line1}, ${booking.address.city}.`,
          type: NotificationType.ASSIGNMENT,
          payload: { bookingId: booking.id, screen: 'job_details' },
        })
        .catch((err) =>
          this.logger.warn(`Failed to notify technician ${selected.user.id}: ${err.message}`),
        );
    }

    // Push notification to Customer (Technician Credentials & Arrival Details)
    if (booking.customer?.user?.id) {
      const techName = selected.user?.name ?? 'Technician';
      const techRating = Number(selected.rating ?? 0).toFixed(1);
      const techPhone = selected.user?.phone ? ` Contact: ${selected.user.phone}` : '';

      await this.notificationService
        .sendPushNotification({
          userId: booking.customer.user.id,
          title: 'Booking Confirmed & Technician Assigned ✅',
          body: `${techName} (★${techRating}) will arrive on ${scheduledDateStr} (${booking.scheduledSlot}) for your ${booking.subService.name}.${techPhone}`,
          type: NotificationType.BOOKING_UPDATE,
          payload: { bookingId: booking.id, screen: 'booking_detail' },
        })
        .catch((err) =>
          this.logger.warn(`Failed to notify customer ${booking.customer.user.id}: ${err.message}`),
        );
    }
  }

  /**
   * Slot-aware matching query for automated assignment.
   */
  private async findEligibleTechniciansForSlot(
    pincode: string,
    subServiceId: string,
    scheduledDate: Date,
    scheduledSlot: string,
  ) {
    const activeJobStatuses: BookingStatus[] = [
      BookingStatus.ASSIGNED,
      BookingStatus.ACCEPTED,
      BookingStatus.EN_ROUTE,
      BookingStatus.ARRIVED,
      BookingStatus.IN_PROGRESS,
    ];

    return this.prisma.technician.findMany({
      where: {
        verificationStatus: VerificationStatus.VERIFIED,
        isAvailable: true,
        deletedAt: null,
        user: { isActive: true, deletedAt: null },
        // Must serve the booking's pincode
        serviceAreas: {
          some: {
            serviceArea: { pincode, isActive: true, deletedAt: null },
          },
        },
        // Must be specialised in the required sub-service
        specializations: {
          some: { subServiceId },
        },
        // Must not already be booked for this scheduledDate & scheduledSlot
        bookings: {
          none: {
            scheduledDate,
            scheduledSlot,
            status: { in: activeJobStatuses },
          },
        },
      },
      include: {
        user: {
          select: { id: true, name: true, phone: true },
        },
      },
      orderBy: [{ rating: 'desc' }, { lastLocationAt: 'desc' }],
    });
  }

  /**
   * Sends an alert notification to all ADMIN users when no technician can be matched.
   */
  private async alertAdminNoTechnicians(booking: {
    id: string;
    bookingNumber: string;
    address: { pincode: string };
    subServiceId: string;
  }): Promise<void> {
    const admins = await this.prisma.user.findMany({
      where: { role: 'ADMIN', isActive: true, deletedAt: null },
      select: { id: true },
    });

    await Promise.allSettled(
      admins.map((admin) =>
        this.notificationService
          .sendPushNotification({
            userId: admin.id,
            title: '⚠️ No Technician Available',
            body: `Booking ${booking.bookingNumber} (pincode: ${booking.address.pincode}) has no eligible technicians or all offers expired. Manual assignment required.`,
            type: NotificationType.SYSTEM,
            payload: { bookingId: booking.id, screen: 'admin_booking_detail' },
          })
          .catch((err) => this.logger.warn(`Failed to alert admin ${admin.id}: ${err.message}`)),
      ),
    );
  }

  /**
   * Checks for CONFIRMED bookings that have no PENDING or ACCEPTED job offers
   * (meaning all offers have expired or been rejected) and:
   *  1. Notifies the customer that we are working on finding a technician.
   *  2. Auto-cancels and marks for refund bookings that have been orphaned for > 2 hours.
   * Called periodically by the job scheduler.
   */
  async checkOrphanedBookings(): Promise<number> {
    const twoHoursAgo = new Date(Date.now() - 2 * 60 * 60 * 1000);

    const orphanedBookings = await this.prisma.booking.findMany({
      where: {
        status: BookingStatus.CONFIRMED,
        jobOffers: {
          none: {
            status: { in: ['PENDING', 'ACCEPTED'] },
          },
        },
      },
      include: {
        address: true,
        customer: { select: { userId: true } },
      },
    });

    let autoCancelledCount = 0;

    for (const booking of orphanedBookings) {
      const isLongOrphaned = booking.updatedAt < twoHoursAgo;

      if (isLongOrphaned) {
        // ── Auto-cancel after 2 hours with no technician ────────────────────
        this.logger.warn(
          `Auto-cancelling booking ${booking.bookingNumber} — orphaned for >2 hours.`,
        );

        await this.prisma.booking.update({
          where: { id: booking.id },
          data: {
            status: BookingStatus.FAILED,
            failedAt: new Date(),
            failureReason: 'No available technician found in your area. Booking auto-cancelled.',
          },
        });

        // Notify customer with apology + refund promise
        if (booking.customer?.userId) {
          await this.notificationService
            .sendPushNotification({
              userId: booking.customer.userId,
              title: '❌ Booking Cancelled — Refund Initiated',
              body: `We're sorry! We couldn't find a technician for booking ${booking.bookingNumber}. Your payment will be refunded within 3–5 business days.`,
              type: NotificationType.BOOKING_UPDATE,
              payload: { bookingId: booking.id, screen: 'booking_detail' },
            })
            .catch((err) =>
              this.logger.warn(
                `Failed to notify customer ${booking.customer.userId}: ${err.message}`,
              ),
            );
        }

        autoCancelledCount++;
      } else {
        // ── Still within tolerance — notify customer we're working on it ────
        this.logger.warn(
          `Booking ${booking.bookingNumber} is orphaned — notifying customer and alerting admins.`,
        );

        if (booking.customer?.userId) {
          await this.notificationService
            .sendPushNotification({
              userId: booking.customer.userId,
              title: '🔍 Finding You a Technician',
              body: `We're still looking for the best technician for booking ${booking.bookingNumber}. We'll notify you as soon as one is assigned. Sorry for the wait!`,
              type: NotificationType.BOOKING_UPDATE,
              payload: { bookingId: booking.id, screen: 'booking_detail' },
            })
            .catch((err) =>
              this.logger.warn(
                `Failed to notify customer ${booking.customer.userId}: ${err.message}`,
              ),
            );
        }

        await this.alertAdminNoTechnicians(booking);
      }
    }

    this.logger.log(
      `Orphaned booking check: ${orphanedBookings.length} found, ${autoCancelledCount} auto-cancelled.`,
    );
    return orphanedBookings.length;
  }
}
