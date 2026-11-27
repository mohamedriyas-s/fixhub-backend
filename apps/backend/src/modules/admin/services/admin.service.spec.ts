import { ErrorCodes } from '@fixhub/shared';
import { NotFoundException } from '@nestjs/common';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { Test, TestingModule } from '@nestjs/testing';
import { VerificationStatus } from '@prisma/client';

import { NotificationService } from '../../notification/services/notification.service';
import { AdminRepository } from '../repositories/admin.repository';
import { AdminService } from './admin.service';
import { AdminNotificationService } from './admin-notification.service';

describe('AdminService', () => {
  let service: AdminService;
  let adminRepository: jest.Mocked<AdminRepository>;
  let notificationService: jest.Mocked<NotificationService>;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AdminService,
        {
          provide: AdminRepository,
          useValue: {
            getDashboardStats: jest.fn(),
            listCustomers: jest.fn(),
            getCustomerDetails: jest.fn(),
            listTechnicians: jest.fn(),
            getTechnicianDetails: jest.fn(),
            updateUserStatus: jest.fn(),
            verifyTechnician: jest.fn(),
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
            sendPushNotification: jest.fn().mockResolvedValue({ queued: true }),
          },
        },
        {
          provide: EventEmitter2,
          useValue: {
            emit: jest.fn(),
          },
        },
      ],
    }).compile();

    service = module.get<AdminService>(AdminService);
    adminRepository = module.get(AdminRepository);
    notificationService = module.get(NotificationService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('getCustomerDetails', () => {
    it('should throw NotFoundException if customer not found', async () => {
      adminRepository.getCustomerDetails.mockResolvedValue(null);

      await expect(service.getCustomerDetails('invalid-id')).rejects.toThrow(NotFoundException);
      await expect(service.getCustomerDetails('invalid-id')).rejects.toMatchObject({
        response: { errorCode: ErrorCodes.CUSTOMER_NOT_FOUND },
      });
    });

    it('should return customer if found', async () => {
      adminRepository.getCustomerDetails.mockResolvedValue({ id: 'valid-id' } as never);

      const result = await service.getCustomerDetails('valid-id');
      expect(result.id).toBe('valid-id');
    });
  });

  describe('verifyTechnician', () => {
    it('should update verification status and notify technician', async () => {
      adminRepository.verifyTechnician.mockResolvedValue({
        id: 'tech-1',
        verificationStatus: VerificationStatus.VERIFIED,
        user: { id: 'tech-user-1', name: 'Ravi', phone: null, isActive: true },
      } as never);

      const result = await service.verifyTechnician('tech-1', VerificationStatus.VERIFIED);
      expect(result.verificationStatus).toBe(VerificationStatus.VERIFIED);
      expect(adminRepository.verifyTechnician).toHaveBeenCalledWith(
        'tech-1',
        VerificationStatus.VERIFIED,
        undefined,
      );
      expect(notificationService.sendPushNotification).toHaveBeenCalledWith(
        expect.objectContaining({
          userId: 'tech-user-1',
          title: expect.stringContaining('Verified'),
        }),
      );
    });

    it('should throw NotFoundException if technician not found', async () => {
      adminRepository.verifyTechnician.mockRejectedValue({ code: 'P2025' });

      await expect(
        service.verifyTechnician('invalid-tech', VerificationStatus.REJECTED, 'Missing docs'),
      ).rejects.toThrow(NotFoundException);
    });
  });
});
