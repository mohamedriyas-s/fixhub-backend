import { Test, TestingModule } from '@nestjs/testing';
import { BookingStatus, NotificationType, VerificationStatus } from '@prisma/client';

import { PrismaService } from '../../../common/database/prisma.service';
import { NotificationService } from '../../notification/services/notification.service';
import { JobOfferRepository } from '../../technician/repositories/job-offer.repository';
import { BookingDispatchService } from './booking-dispatch.service';

describe('BookingDispatchService', () => {
  let service: BookingDispatchService;
  let prisma: any;
  let notificationService: any;
  let jobOfferRepository: any;

  const mockDate = new Date('2026-11-20T10:00:00Z');
  const mockBooking = {
    id: 'booking-uuid-1',
    bookingNumber: 'FH-20261120-0001',
    status: BookingStatus.CONFIRMED,
    technicianId: null,
    subServiceId: 'sub-service-uuid-1',
    scheduledDate: mockDate,
    scheduledSlot: '10:00 AM - 12:00 PM',
    address: {
      id: 'addr-1',
      pincode: '600001',
      line1: '123 Main St',
      city: 'Chennai',
    },
    subService: {
      id: 'sub-service-uuid-1',
      name: 'Fan Repair',
    },
    customer: {
      id: 'cust-1',
      user: {
        id: 'cust-user-1',
        name: 'John Doe',
        phone: '+919876543210',
      },
    },
  };

  const mockTech1 = {
    id: 'tech-1',
    userId: 'tech-user-1',
    rating: 4.8,
    verificationStatus: VerificationStatus.VERIFIED,
    isAvailable: true,
    user: {
      id: 'tech-user-1',
      name: 'Ramesh Kumar',
      phone: '+919123456789',
    },
  };

  const mockTech2 = {
    id: 'tech-2',
    userId: 'tech-user-2',
    rating: 4.5,
    verificationStatus: VerificationStatus.VERIFIED,
    isAvailable: true,
    user: {
      id: 'tech-user-2',
      name: 'Suresh Raina',
      phone: '+919988776655',
    },
  };

  beforeEach(async () => {
    prisma = {
      booking: {
        findUnique: jest.fn(),
        count: jest.fn(),
        update: jest.fn(),
      },
      technician: {
        findMany: jest.fn(),
      },
      user: {
        findMany: jest.fn(),
      },
      bookingTimeline: {
        create: jest.fn(),
      },
      $transaction: jest.fn(async (cb) => cb(prisma)),
    };

    notificationService = {
      sendPushNotification: jest.fn().mockResolvedValue({ success: true }),
    };

    jobOfferRepository = {
      createOffers: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        BookingDispatchService,
        { provide: PrismaService, useValue: prisma },
        { provide: NotificationService, useValue: notificationService },
        { provide: JobOfferRepository, useValue: jobOfferRepository },
      ],
    }).compile();

    service = module.get<BookingDispatchService>(BookingDispatchService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('dispatch', () => {
    it('should skip dispatch if booking not found', async () => {
      prisma.booking.findUnique.mockResolvedValue(null);

      await service.dispatch('non-existent');

      expect(prisma.technician.findMany).not.toHaveBeenCalled();
      expect(prisma.booking.update).not.toHaveBeenCalled();
    });

    it('should skip dispatch if booking status is not CONFIRMED or PENDING_PAYMENT', async () => {
      prisma.booking.findUnique.mockResolvedValue({
        ...mockBooking,
        status: BookingStatus.DRAFT,
      });

      await service.dispatch('booking-uuid-1');

      expect(prisma.technician.findMany).not.toHaveBeenCalled();
      expect(prisma.booking.update).not.toHaveBeenCalled();
    });

    it('should skip dispatch if booking is already assigned', async () => {
      prisma.booking.findUnique.mockResolvedValue({
        ...mockBooking,
        technicianId: 'already-assigned-tech',
      });

      await service.dispatch('booking-uuid-1');

      expect(prisma.technician.findMany).not.toHaveBeenCalled();
      expect(prisma.booking.update).not.toHaveBeenCalled();
    });

    it('should alert admin when no eligible technicians are available', async () => {
      prisma.booking.findUnique.mockResolvedValue(mockBooking);
      prisma.technician.findMany.mockResolvedValue([]);
      prisma.user.findMany.mockResolvedValue([{ id: 'admin-1' }, { id: 'admin-2' }]);

      await service.dispatch('booking-uuid-1');

      expect(prisma.technician.findMany).toHaveBeenCalled();
      expect(prisma.user.findMany).toHaveBeenCalledWith({
        where: { role: 'ADMIN', isActive: true, deletedAt: null },
        select: { id: true },
      });
      expect(notificationService.sendPushNotification).toHaveBeenCalledWith(
        expect.objectContaining({
          userId: 'admin-1',
          type: NotificationType.SYSTEM,
        }),
      );
      expect(prisma.booking.update).not.toHaveBeenCalled();
    });

    it('should auto-assign the best eligible technician and send notifications', async () => {
      prisma.booking.findUnique.mockResolvedValue(mockBooking);
      prisma.technician.findMany.mockResolvedValue([mockTech1, mockTech2]);

      // Tech 1 has 1 daily job, Tech 2 has 0 daily jobs -> Tech 2 should be chosen for workload balance
      prisma.booking.count.mockImplementation(async ({ where }: any) => {
        if (where.technicianId === 'tech-1') return 1;
        if (where.technicianId === 'tech-2') return 0;
        return 0;
      });

      await service.dispatch('booking-uuid-1');

      expect(prisma.$transaction).toHaveBeenCalled();
      expect(prisma.booking.update).toHaveBeenCalledWith({
        where: { id: mockBooking.id },
        data: {
          technicianId: 'tech-2',
          status: BookingStatus.ASSIGNED,
        },
      });

      expect(prisma.bookingTimeline.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          bookingId: mockBooking.id,
          status: BookingStatus.ASSIGNED,
        }),
      });

      // Notification sent to technician
      expect(notificationService.sendPushNotification).toHaveBeenCalledWith(
        expect.objectContaining({
          userId: 'tech-user-2',
          type: NotificationType.ASSIGNMENT,
          payload: { bookingId: mockBooking.id, screen: 'job_details' },
        }),
      );

      // Notification sent to customer
      expect(notificationService.sendPushNotification).toHaveBeenCalledWith(
        expect.objectContaining({
          userId: 'cust-user-1',
          type: NotificationType.BOOKING_UPDATE,
          payload: { bookingId: mockBooking.id, screen: 'booking_detail' },
        }),
      );
    });

    it('should rank by rating when technicians have equal daily workload', async () => {
      prisma.booking.findUnique.mockResolvedValue(mockBooking);
      prisma.technician.findMany.mockResolvedValue([mockTech2, mockTech1]); // Tech1 has 4.8 rating, Tech2 has 4.5

      // Equal workload
      prisma.booking.count.mockResolvedValue(0);

      await service.dispatch('booking-uuid-1');

      // Tech 1 has higher rating (4.8 vs 4.5), so Tech 1 is selected
      expect(prisma.booking.update).toHaveBeenCalledWith({
        where: { id: mockBooking.id },
        data: {
          technicianId: 'tech-1',
          status: BookingStatus.ASSIGNED,
        },
      });
    });
  });
});
