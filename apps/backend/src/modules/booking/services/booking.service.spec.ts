import { ConflictException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { BookingStatus, Role } from '@prisma/client';

import { PrismaService } from '../../../common/database/prisma.service';
import { StorageService } from '../../../common/storage/storage.service';
import { AdminNotificationService } from '../../admin/services/admin-notification.service';
import { NotificationService } from '../../notification/services/notification.service';
import { BookingRepository } from '../repositories/booking.repository';
import { BookingService } from './booking.service';
import { BookingLockService } from './booking-lock.service';
import { BookingQueryCacheService } from './booking-query-cache.service';

describe('BookingService creation', () => {
  let service: BookingService;
  let repository: jest.Mocked<BookingRepository>;
  let lockService: jest.Mocked<BookingLockService>;
  let storageService: jest.Mocked<StorageService>;
  let queryCacheService: jest.Mocked<BookingQueryCacheService>;
  let prisma: any;

  const user = {
    userId: 'user-uuid-1',
    phone: '+919876543210',
    role: Role.CUSTOMER,
  };
  const customer = {
    id: 'customer-uuid-1',
    userId: user.userId,
    user: { id: user.userId, isActive: true, deletedAt: null },
  };
  const address = {
    id: 'address-uuid-1',
    customerId: customer.id,
    label: 'Home',
    line1: 'Street',
    city: 'Chennai',
    state: 'Tamil Nadu',
    pincode: '600099',
  };
  const serviceItem = {
    id: 'service-uuid-1',
    name: 'Fan Repair',
    basePrice: 499,
    estimatedDurationMins: 60,
    category: { id: 'category-uuid-1', name: 'Electrical' },
  };
  const serviceArea = {
    id: 'service-area-uuid-1',
    name: 'Kolathur',
    pincode: '600099',
  };
  const dto = {
    subServiceId: serviceItem.id,
    addressId: address.id,
    scheduledDate: '2099-07-20',
    scheduledSlot: '10:00-12:00',
    description: 'Fan is noisy',
  };
  const booking = {
    id: 'booking-uuid-1',
    bookingNumber: 'FH-20990720-0001',
    customerId: customer.id,
    addressId: address.id,
    subServiceId: serviceItem.id,
    scheduledDate: new Date('2099-07-20T00:00:00.000Z'),
    scheduledSlot: dto.scheduledSlot,
    status: BookingStatus.DRAFT,
    address,
    subService: serviceItem,
    media: [],
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        BookingService,
        {
          provide: BookingRepository,
          useValue: {
            findByUser: jest.fn(),
            findById: jest.fn(),
            findCustomerByUserId: jest.fn(),
            findAddressForCustomer: jest.fn(),
            findActiveService: jest.fn(),
            findActiveServiceAreaByPincode: jest.fn(),
            countSlotConflicts: jest.fn(),
            countServiceCapacity: jest.fn().mockResolvedValue(5),
            countSlotBookings: jest.fn().mockResolvedValue(0),
            createBooking: jest.fn(),
            updateBookingStatus: jest.fn(),
            updateDraftAndConfirm: jest.fn(),
            findDraftForCustomer: jest.fn(),
            createMedia: jest.fn(),
            setPriceRevision: jest.fn(),
            approveRevision: jest.fn(),
            rejectRevision: jest.fn(),
            updateIssueDetails: jest.fn(),
            updateLifecycleStatus: jest.fn(),
            createTimelineEntry: jest.fn(),
            findTechnicianProfileByUserId: jest.fn(),
            transaction: jest.fn((fn) => fn({})),
          },
        },
        {
          provide: BookingLockService,
          useValue: {
            acquire: jest.fn(),
            release: jest.fn(),
            nextBookingNumber: jest.fn(),
            setDraftExpiry: jest.fn(),
            isDraftActive: jest.fn(),
            clearDraftExpiry: jest.fn(),
          },
        },
        {
          provide: StorageService,
          useValue: {
            generateKey: jest.fn(),
            getUploadUrl: jest.fn(),
          },
        },
        {
          provide: BookingQueryCacheService,
          useValue: {
            invalidate: jest.fn(),
          },
        },
        {
          provide: PrismaService,
          useValue: {
            technician: { findUnique: jest.fn(), count: jest.fn(), findMany: jest.fn() },
            customer: { findUnique: jest.fn() },
            booking: { findFirst: jest.fn(), update: jest.fn(), findMany: jest.fn() },
          },
        },
        {
          provide: AdminNotificationService,
          useValue: {
            createAndBroadcast: jest.fn().mockResolvedValue(undefined),
          },
        },
        {
          provide: NotificationService,
          useValue: {
            sendPushNotification: jest.fn().mockResolvedValue(undefined),
          },
        },
      ],
    }).compile();

    service = module.get(BookingService);
    repository = module.get(BookingRepository);
    lockService = module.get(BookingLockService);
    storageService = module.get(StorageService);
    queryCacheService = module.get(BookingQueryCacheService);
    prisma = module.get(PrismaService);

    repository.findCustomerByUserId.mockResolvedValue(customer as never);
    repository.findAddressForCustomer.mockResolvedValue(address as never);
    repository.findActiveServiceAreaByPincode.mockResolvedValue(serviceArea as never);
    repository.findActiveService.mockResolvedValue(serviceItem as never);
    repository.countSlotConflicts.mockResolvedValue(0);
    lockService.acquire.mockResolvedValue('lock-token');
    lockService.nextBookingNumber.mockResolvedValue('FH-20990720-0001');
    repository.createBooking.mockResolvedValue(booking as never);
  });

  it('returns a booking summary after validating customer, address, area, service, and slot', async () => {
    const result = await service.getSummary(user, dto);

    expect(result.service.id).toBe(serviceItem.id);
    expect(result.address.id).toBe(address.id);
    expect(result.serviceArea.id).toBe(serviceArea.id);
    expect(result.pricing.total).toBe(499);
  });

  it('rejects non-customer booking creation', async () => {
    await expect(service.getSummary({ ...user, role: Role.TECHNICIAN }, dto)).rejects.toThrow(
      ForbiddenException,
    );
  });

  it('throws when customer address is missing', async () => {
    repository.findAddressForCustomer.mockResolvedValue(null);

    await expect(service.getSummary(user, dto)).rejects.toThrow(NotFoundException);
  });

  it('creates a draft booking with a Redis slot lock and draft expiry', async () => {
    const result = await service.createDraft(user, dto);

    expect(result.booking.id).toBe(booking.id);
    expect(lockService.acquire).toHaveBeenCalledWith(
      expect.stringContaining(`${address.id}:2099-07-20:${dto.scheduledSlot}`),
    );
    expect(repository.createBooking).toHaveBeenCalledWith(
      {},
      expect.objectContaining({
        status: BookingStatus.DRAFT,
        bookingNumber: 'FH-20990720-0001',
      }),
    );
    expect(lockService.setDraftExpiry).toHaveBeenCalledWith(booking.id, 600);
    expect(lockService.release).toHaveBeenCalledWith(expect.any(String), 'lock-token');
    expect(queryCacheService.invalidate).toHaveBeenCalled();
  });

  it('throws when the Redis slot lock cannot be acquired', async () => {
    lockService.acquire.mockResolvedValue(null);

    await expect(service.createDraft(user, dto)).rejects.toThrow(ConflictException);
  });

  it('throws when a slot conflict exists', async () => {
    repository.countSlotConflicts.mockResolvedValue(1);

    await expect(service.createDraft(user, dto)).rejects.toThrow(ConflictException);
    expect(lockService.release).toHaveBeenCalled();
  });

  it('confirms an active draft booking', async () => {
    repository.findDraftForCustomer.mockResolvedValue(booking as never);
    lockService.isDraftActive.mockResolvedValue(true);
    repository.updateBookingStatus.mockResolvedValue({
      ...booking,
      status: BookingStatus.CONFIRMED,
    } as never);

    const result = await service.confirmBooking(user, booking.id, {});

    expect(result.confirmation.status).toBe(BookingStatus.CONFIRMED);
    expect(repository.updateBookingStatus).toHaveBeenCalledWith(
      {},
      booking.id,
      BookingStatus.CONFIRMED,
      user.userId,
      expect.any(String),
    );
    expect(lockService.clearDraftExpiry).toHaveBeenCalledWith(booking.id);
    expect(queryCacheService.invalidate).toHaveBeenCalled();
  });

  it('rejects expired draft confirmation', async () => {
    repository.findDraftForCustomer.mockResolvedValue(booking as never);
    lockService.isDraftActive.mockResolvedValue(false);

    await expect(service.confirmBooking(user, booking.id, {})).rejects.toThrow();
  });

  it('prepares media upload and persists media when URL is supplied', async () => {
    repository.findById.mockResolvedValue({ ...booking, status: BookingStatus.DRAFT } as never);
    storageService.generateKey.mockReturnValue('bookings/booking-uuid-1/photo.jpg');
    storageService.getUploadUrl.mockResolvedValue('https://signed-upload-url');
    repository.createMedia.mockResolvedValue({ id: 'media-uuid-1' } as never);

    const result = await service.prepareMediaUpload(user, booking.id, {
      fileName: 'photo.jpg',
      contentType: 'image/jpeg',
      url: 'https://cdn.fixhub.in/photo.jpg',
    });

    expect(result.uploadUrl).toBe('https://signed-upload-url');
    expect(repository.createMedia).toHaveBeenCalled();
    expect(queryCacheService.invalidate).toHaveBeenCalled();
  });

  it('cancels draft booking and clears draft expiry to release slot lock', async () => {
    (prisma.booking.findFirst as jest.Mock).mockResolvedValue({
      id: booking.id,
      customerId: customer.id,
      status: BookingStatus.DRAFT,
    });
    (prisma.booking.update as jest.Mock).mockResolvedValue({
      id: booking.id,
      status: BookingStatus.CANCELLED,
    });

    const result = await service.cancelDraft(user, booking.id);

    expect(result.message).toContain('cancelled and slot released');
    expect(lockService.clearDraftExpiry).toHaveBeenCalledWith(booking.id);
    expect(queryCacheService.invalidate).toHaveBeenCalled();
  });

  it('cancels pending payment booking and clears draft expiry to release slot lock', async () => {
    (prisma.booking.findFirst as jest.Mock).mockResolvedValue({
      id: booking.id,
      customerId: customer.id,
      status: BookingStatus.PENDING_PAYMENT,
    });
    (prisma.booking.update as jest.Mock).mockResolvedValue({
      id: booking.id,
      status: BookingStatus.CANCELLED,
    });

    const result = await service.cancelDraft(user, booking.id);

    expect(result.message).toContain('cancelled and slot released');
    expect(lockService.clearDraftExpiry).toHaveBeenCalledWith(booking.id);
    expect(queryCacheService.invalidate).toHaveBeenCalled();
  });

  it('checks technician availability in service area for pre-flight check', async () => {
    (prisma.technician.count as jest.Mock).mockResolvedValue(2);

    const result = await service.checkTechniciansAvailable({
      subServiceId: 'sub-service-uuid',
      pincode: '600099',
    });

    expect(result.available).toBe(true);
    expect(result.count).toBe(2);
  });

  it('proposes an additional charge with description, reason, and amount', async () => {
    const techUser = { userId: 'tech-user-uuid', phone: '+919999999999', role: Role.TECHNICIAN };
    repository.findTechnicianProfileByUserId.mockResolvedValue({ id: 'tech-uuid-1' } as never);
    repository.findById.mockResolvedValue({
      id: booking.id,
      technicianId: 'tech-uuid-1',
      customerId: customer.id,
      bookingNumber: 'FH-1234',
      status: BookingStatus.IN_PROGRESS,
      totalAmount: 100,
    } as never);
    repository.setPriceRevision.mockResolvedValue({
      id: booking.id,
      status: BookingStatus.PRICE_REVISION_PENDING,
      totalAmount: 100,
      revisedAmount: 150,
      additionalAmount: 50,
      priceRevisionDescription: 'Capacitor replacement',
      priceRevisionNote: 'Burnt coil',
    } as never);

    const result = await service.proposeAdditionalCharge(techUser, booking.id, {
      amount: 50,
      description: 'Capacitor replacement',
      reason: 'Burnt coil',
    });

    expect(result.status).toBe(BookingStatus.PRICE_REVISION_PENDING);
    expect(repository.setPriceRevision).toHaveBeenCalledWith(
      expect.anything(),
      booking.id,
      expect.objectContaining({
        revisedAmount: 150,
        additionalAmount: 50,
        description: 'Capacitor replacement',
        note: 'Burnt coil',
      }),
      techUser.userId,
    );
    expect(repository.createTimelineEntry).toHaveBeenCalled();
    expect(queryCacheService.invalidate).toHaveBeenCalled();
  });

  it('proposes an additional charge with optional description and reason omitted', async () => {
    const techUser = { userId: 'tech-user-uuid', phone: '+919999999999', role: Role.TECHNICIAN };
    repository.findTechnicianProfileByUserId.mockResolvedValue({ id: 'tech-uuid-1' } as never);
    repository.findById.mockResolvedValue({
      id: booking.id,
      technicianId: 'tech-uuid-1',
      customerId: customer.id,
      bookingNumber: 'FH-1234',
      status: BookingStatus.IN_PROGRESS,
      totalAmount: 200,
    } as never);
    repository.setPriceRevision.mockResolvedValue({
      id: booking.id,
      status: BookingStatus.PRICE_REVISION_PENDING,
      totalAmount: 200,
      revisedAmount: 275,
      additionalAmount: 75,
    } as never);

    const result = await service.proposeAdditionalCharge(techUser, booking.id, {
      amount: 75,
    });

    expect(result.status).toBe(BookingStatus.PRICE_REVISION_PENDING);
    expect(repository.setPriceRevision).toHaveBeenCalledWith(
      expect.anything(),
      booking.id,
      expect.objectContaining({
        revisedAmount: 275,
        additionalAmount: 75,
        description: undefined,
        note: undefined,
      }),
      techUser.userId,
    );
  });

  it('allows customer to approve price revision and transitions back to IN_PROGRESS', async () => {
    repository.findCustomerByUserId.mockResolvedValue(customer as never);
    repository.findById.mockResolvedValue({
      id: booking.id,
      customerId: customer.id,
      status: BookingStatus.PRICE_REVISION_PENDING,
      totalAmount: 100,
      revisedAmount: 150,
      additionalAmount: 50,
      technician: { userId: 'tech-user-123' },
    } as never);
    repository.approveRevision.mockResolvedValue({
      id: booking.id,
      status: BookingStatus.IN_PROGRESS,
      totalAmount: 150,
      revisedAmount: null,
    } as never);

    const result = await service.approveRevision(user, booking.id);

    expect(result.status).toBe(BookingStatus.IN_PROGRESS);
    expect(result.totalAmount).toBe(150);
    expect(repository.approveRevision).toHaveBeenCalledWith(
      expect.anything(),
      booking.id,
      user.userId,
    );
    expect(repository.createTimelineEntry).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({
        bookingId: booking.id,
        status: BookingStatus.IN_PROGRESS,
        note: expect.stringContaining('approved by customer'),
      }),
    );
    expect(queryCacheService.invalidate).toHaveBeenCalled();
  });

  it('rejects approval if booking status is not PRICE_REVISION_PENDING', async () => {
    repository.findCustomerByUserId.mockResolvedValue(customer as never);
    repository.findById.mockResolvedValue({
      id: booking.id,
      customerId: customer.id,
      status: BookingStatus.IN_PROGRESS,
    } as never);

    await expect(service.approveRevision(user, booking.id)).rejects.toThrow();
  });

  it('allows customer to reject price revision and reverts to IN_PROGRESS with original scope', async () => {
    repository.findCustomerByUserId.mockResolvedValue(customer as never);
    repository.findById.mockResolvedValue({
      id: booking.id,
      customerId: customer.id,
      status: BookingStatus.PRICE_REVISION_PENDING,
      totalAmount: 100,
      revisedAmount: 150,
      additionalAmount: 50,
      technician: { userId: 'tech-user-123' },
    } as never);
    repository.rejectRevision.mockResolvedValue({
      id: booking.id,
      status: BookingStatus.IN_PROGRESS,
      totalAmount: 100,
      revisedAmount: null,
      additionalAmount: null,
    } as never);

    const result = await service.rejectRevision(user, booking.id);

    expect(result.status).toBe(BookingStatus.IN_PROGRESS);
    expect(result.totalAmount).toBe(100);
    expect(repository.rejectRevision).toHaveBeenCalledWith(
      expect.anything(),
      booking.id,
      user.userId,
    );
    expect(repository.createTimelineEntry).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({
        bookingId: booking.id,
        status: BookingStatus.IN_PROGRESS,
        note: expect.stringContaining('declined by customer'),
      }),
    );
    expect(queryCacheService.invalidate).toHaveBeenCalled();
  });

  it('updates issue details for customer before service completion', async () => {
    repository.findCustomerByUserId.mockResolvedValue(customer as never);
    repository.findById.mockResolvedValue({
      id: booking.id,
      customerId: customer.id,
      status: BookingStatus.CONFIRMED,
      technician: { userId: 'tech-user-123' },
    } as never);
    repository.updateIssueDetails.mockResolvedValue({
      id: booking.id,
      description: 'Water leak from internal condenser',
    } as never);

    const result = await service.updateIssueDetails(user, booking.id, {
      description: 'Water leak from internal condenser',
    });

    expect(result.description).toBe('Water leak from internal condenser');
    expect(repository.updateIssueDetails).toHaveBeenCalledWith(
      booking.id,
      'Water leak from internal condenser',
      user.userId,
    );
    expect(queryCacheService.invalidate).toHaveBeenCalled();
  });

  it('rejects issue update after booking is completed', async () => {
    repository.findCustomerByUserId.mockResolvedValue(customer as never);
    repository.findById.mockResolvedValue({
      id: booking.id,
      customerId: customer.id,
      status: BookingStatus.COMPLETED,
    } as never);

    await expect(
      service.updateIssueDetails(user, booking.id, { description: 'Too late' }),
    ).rejects.toThrow();
  });
});
