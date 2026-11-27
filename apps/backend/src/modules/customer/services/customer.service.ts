import { ErrorCodes } from '@fixhub/shared';
import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';

import { CustomerRepository } from '../repositories/customer.repository';

@Injectable()
export class CustomerService {
  constructor(private readonly customerRepository: CustomerRepository) {}

  async getProfile(userId: string) {
    const customer = await this.customerRepository.findByUserId(userId);

    if (!customer) {
      throw new NotFoundException({
        message: 'Customer not found',
        errorCode: ErrorCodes.USER_NOT_FOUND,
      });
    }

    return customer;
  }

  async updateProfile(userId: string, data: any) {
    return this.customerRepository.updateProfile(userId, data);
  }

  async getAddresses(userId: string) {
    return this.customerRepository.getAddresses(userId);
  }

  async addAddress(userId: string, data: any) {
    const pincode = data.pincode ?? data.postalCode;
    if (!pincode || typeof pincode !== 'string' || pincode.trim().length !== 6) {
      throw new BadRequestException({
        message: 'A valid 6-digit postal pincode is required',
        errorCode: ErrorCodes.VALIDATION_ERROR,
      });
    }

    const serviceArea = await this.customerRepository.findActiveServiceAreaByPincode(pincode);
    if (!serviceArea) {
      throw new BadRequestException({
        message: `FixHub services are not currently available in pincode ${pincode.trim()}. Please enter an address in our active service area.`,
        errorCode: ErrorCodes.SERVICE_AREA_NOT_FOUND,
      });
    }

    return this.customerRepository.addAddress(userId, data);
  }

  async updateAddress(userId: string, addressId: string, data: any) {
    const pincode = data.pincode ?? data.postalCode;
    if (pincode !== undefined) {
      if (typeof pincode !== 'string' || pincode.trim().length !== 6) {
        throw new BadRequestException({
          message: 'A valid 6-digit postal pincode is required',
          errorCode: ErrorCodes.VALIDATION_ERROR,
        });
      }

      const serviceArea = await this.customerRepository.findActiveServiceAreaByPincode(pincode);
      if (!serviceArea) {
        throw new BadRequestException({
          message: `FixHub services are not currently available in pincode ${pincode.trim()}. Please enter an address in our active service area.`,
          errorCode: ErrorCodes.SERVICE_AREA_NOT_FOUND,
        });
      }
    }

    return this.customerRepository.updateAddress(addressId, data);
  }

  async deleteAddress(userId: string, addressId: string) {
    return this.customerRepository.deleteAddress(addressId);
  }

  async setDefaultAddress(userId: string, addressId: string) {
    return this.customerRepository.setDefaultAddress(userId, addressId);
  }
}
