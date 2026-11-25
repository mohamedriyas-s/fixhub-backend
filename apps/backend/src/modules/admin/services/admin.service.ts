import { ErrorCodes } from '@fixhub/shared';
import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { VerificationStatus } from '@prisma/client';

import {
  CouponQueryDto,
  CreateCouponDto,
  CreateCustomerDto,
  CreatePricingRuleDto,
  CreateTechnicianDto,
  CustomerQueryDto,
  PaymentQueryDto,
  TechnicianQueryDto,
  UpdateCouponDto,
  UpdateCustomerDetailsDto,
  UpdatePricingRuleDto,
  UpdateTechnicianDetailsDto,
} from '../dto/admin.dto';
import { AdminRepository } from '../repositories/admin.repository';
import { AdminNotificationService, AdminNotifType } from './admin-notification.service';

@Injectable()
export class AdminService {
  constructor(
    private readonly adminRepository: AdminRepository,
    private readonly adminNotifService: AdminNotificationService,
    private readonly eventEmitter: EventEmitter2,
  ) {}

  async getDashboardStats() {
    return this.adminRepository.getDashboardStats();
  }

  // ── Customers ─────────────────────────────────────────────

  async listCustomers(query: CustomerQueryDto) {
    return this.adminRepository.listCustomers(query);
  }

  async listPayments(query: PaymentQueryDto) {
    return this.adminRepository.listPayments(query);
  }

  async getCustomerDetails(id: string) {
    const customer = await this.adminRepository.getCustomerDetails(id);
    if (!customer) {
      throw new NotFoundException({
        message: 'Customer not found',
        errorCode: ErrorCodes.CUSTOMER_NOT_FOUND,
      });
    }
    return customer;
  }

  async createCustomer(dto: CreateCustomerDto) {
    return this.adminRepository.createCustomer(dto);
  }

  async updateCustomerDetails(id: string, dto: UpdateCustomerDetailsDto) {
    const result = await this.adminRepository.updateCustomerDetails(id, dto);
    if (!result) {
      throw new NotFoundException({
        message: 'Customer not found',
        errorCode: ErrorCodes.CUSTOMER_NOT_FOUND,
      });
    }
    return result;
  }

  async notifyCustomerCompleteProfile(customerId: string, message: string) {
    const customer = await this.adminRepository.getCustomerDetails(customerId);
    if (!customer) {
      throw new NotFoundException({
        message: 'Customer not found',
        errorCode: ErrorCodes.CUSTOMER_NOT_FOUND,
      });
    }
    // Notify admin of the action as well
    await this.adminNotifService.createAndBroadcast(
      AdminNotifType.SYSTEM,
      '📣 Customer Profile Notification Sent',
      `Notification sent to customer ${customer.user?.name ?? customerId} to complete their profile.`,
      { customerId, message },
    );
    return { success: true };
  }

  // ── Technicians ───────────────────────────────────────────

  async listTechnicians(query: TechnicianQueryDto) {
    return this.adminRepository.listTechnicians(query);
  }

  async getTechnicianDetails(id: string) {
    const technician = await this.adminRepository.getTechnicianDetails(id);
    if (!technician) {
      throw new NotFoundException({
        message: 'Technician not found',
        errorCode: ErrorCodes.TECHNICIAN_NOT_FOUND,
      });
    }
    return technician;
  }

  async notifyTechnicianCompleteProfile(technicianId: string, message: string) {
    const technician = await this.adminRepository.getTechnicianDetails(technicianId);
    if (!technician) {
      throw new NotFoundException({
        message: 'Technician not found',
        errorCode: ErrorCodes.TECHNICIAN_NOT_FOUND,
      });
    }
    await this.adminNotifService.createAndBroadcast(
      AdminNotifType.SYSTEM,
      '📣 Technician Profile Notification Sent',
      `Notification sent to technician ${technician.user?.name ?? technicianId} to complete their profile.`,
      { technicianId, message },
    );
    return { success: true };
  }

  async createTechnician(dto: CreateTechnicianDto) {
    const tech = await this.adminRepository.createTechnician(dto);
    this.eventEmitter.emit('technician.created', tech.id);
    return tech;
  }

  async updateTechnicianDetails(id: string, dto: UpdateTechnicianDetailsDto) {
    const result = await this.adminRepository.updateTechnicianDetails(id, dto);
    if (!result) {
      throw new NotFoundException({
        message: 'Technician not found',
        errorCode: ErrorCodes.TECHNICIAN_NOT_FOUND,
      });
    }
    this.eventEmitter.emit('technician.updated', id);
    return result;
  }

  async addSpecialization(technicianId: string, subServiceId: string) {
    const res = await this.adminRepository.addSpecialization(technicianId, subServiceId);
    this.eventEmitter.emit('technician.specialization_added', technicianId);
    return res;
  }

  async removeSpecialization(technicianId: string, subServiceId: string) {
    const res = await this.adminRepository.removeSpecialization(technicianId, subServiceId);
    this.eventEmitter.emit('technician.specialization_removed', technicianId);
    return res;
  }

  async addServiceArea(technicianId: string, serviceAreaId: string) {
    const res = await this.adminRepository.addServiceArea(technicianId, serviceAreaId);
    this.eventEmitter.emit('technician.area_added', technicianId);
    return res;
  }

  async removeServiceArea(technicianId: string, serviceAreaId: string) {
    const res = await this.adminRepository.removeServiceArea(technicianId, serviceAreaId);
    this.eventEmitter.emit('technician.area_removed', technicianId);
    return res;
  }

  async getEligibleTechnicians(subServiceId: string, pincode: string) {
    return this.adminRepository.getEligibleTechnicians(subServiceId, pincode);
  }

  async updateUserStatus(userId: string, isActive: boolean) {
    try {
      const res = await this.adminRepository.updateUserStatus(userId, isActive);
      this.eventEmitter.emit('technician.status_changed', userId);
      return res;
    } catch (e: any) {
      if (e.code === 'P2025') {
        throw new NotFoundException({
          message: 'User not found',
          errorCode: ErrorCodes.USER_NOT_FOUND,
        });
      }
      throw e;
    }
  }

  async verifyTechnician(id: string, status: VerificationStatus, rejectionNote?: string) {
    try {
      const result = await this.adminRepository.verifyTechnician(id, status, rejectionNote);
      this.eventEmitter.emit('technician.verified', id);

      if (status === VerificationStatus.VERIFIED) {
        await this.adminNotifService.createAndBroadcast(
          AdminNotifType.TECHNICIAN_VERIFIED,
          '✅ Technician Verified',
          `Technician ID ${id} has been verified and is now active.`,
          { technicianId: id, status },
        );
      } else if (status === VerificationStatus.REJECTED) {
        await this.adminNotifService.createAndBroadcast(
          AdminNotifType.TECHNICIAN_REJECTED,
          '❌ Technician Rejected',
          `Technician ID ${id} verification was rejected.${rejectionNote ? ` Reason: ${rejectionNote}` : ''}`,
          { technicianId: id, status, rejectionNote },
        );
      }

      return result;
    } catch (e: any) {
      if (e.code === 'P2025') {
        throw new NotFoundException({
          message: 'Technician not found',
          errorCode: ErrorCodes.TECHNICIAN_NOT_FOUND,
        });
      }
      throw e;
    }
  }

  async listBookings(query: any) {
    // Basic implementation for listing bookings
    return this.adminRepository.listBookings(query);
  }

  async getBookingDetails(id: string) {
    const booking = await this.adminRepository.getBookingDetails(id);
    if (!booking) throw new NotFoundException('Booking not found');
    return booking;
  }

  async createAdminBooking(dto: {
    customerId: string;
    subServiceId: string;
    addressId: string;
    technicianId?: string;
    scheduledDate: string;
    scheduledSlot: string;
    description?: string;
    totalAmount: number;
    adminUserId: string;
  }) {
    return this.adminRepository.createAdminBooking(dto);
  }

  async softDeleteBooking(id: string, reason: string, adminUserId: string) {
    try {
      return await this.adminRepository.softDeleteBooking(id, reason, adminUserId);
    } catch (e: any) {
      if (e.code === 'P2025') {
        throw new NotFoundException({ message: 'Booking not found' });
      }
      throw e;
    }
  }

  async cancelBooking(id: string, reason: string, adminUserId: string) {
    if (!reason?.trim()) {
      throw new BadRequestException({ message: 'Cancellation reason is required' });
    }
    try {
      return await this.adminRepository.cancelBooking(id, reason, adminUserId);
    } catch (e: any) {
      if (e.code === 'P2025') {
        throw new NotFoundException({ message: 'Booking not found' });
      }
      throw e;
    }
  }

  // ── Pricing ───────────────────────────────────────────────

  async listPricingRules() {
    return this.adminRepository.listPricingRules();
  }

  async createPricingRule(dto: CreatePricingRuleDto, adminUserId: string) {
    return this.adminRepository.createPricingRule(dto, adminUserId);
  }

  async updatePricingRule(id: string, dto: UpdatePricingRuleDto, adminUserId: string) {
    return this.adminRepository.updatePricingRule(id, dto, adminUserId);
  }

  async deletePricingRule(id: string) {
    return this.adminRepository.deletePricingRule(id);
  }

  // ── Coupons ───────────────────────────────────────────────

  async listCoupons(query: CouponQueryDto) {
    return this.adminRepository.listCoupons(query);
  }

  async createCoupon(dto: CreateCouponDto, adminUserId: string) {
    return this.adminRepository.createCoupon(dto as any, adminUserId);
  }

  async updateCoupon(id: string, dto: UpdateCouponDto) {
    return this.adminRepository.updateCoupon(id, dto as any);
  }

  async deleteCoupon(id: string) {
    return this.adminRepository.deleteCoupon(id);
  }
}
