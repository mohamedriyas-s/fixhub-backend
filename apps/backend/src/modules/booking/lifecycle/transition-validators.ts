import { ErrorCodes } from '@fixhub/shared';
import { BadRequestException, ForbiddenException } from '@nestjs/common';
import { BookingStatus, Role } from '@prisma/client';

import { BookingTransitionContext, BookingTransitionValidator } from './booking-transition.types';

export class ActorRoleValidator implements BookingTransitionValidator {
  constructor(private readonly allowedRoles: Role[]) {}

  validate({ actor }: BookingTransitionContext): void {
    if (!this.allowedRoles.includes(actor.role as Role)) {
      throw new ForbiddenException({
        message: 'Actor is not allowed to perform this booking transition',
        errorCode: ErrorCodes.AUTH_FORBIDDEN,
      });
    }
  }
}

export class CustomerOwnsBookingValidator implements BookingTransitionValidator {
  validate({ actor, booking }: BookingTransitionContext): void {
    const applies = actor.role === Role.CUSTOMER;
    const valid = booking.customer?.userId === actor.userId;

    if (applies && !valid) {
      throw new ForbiddenException({
        message: 'Customer cannot update another customer booking',
        errorCode: ErrorCodes.AUTH_FORBIDDEN,
      });
    }
  }
}

export class TechnicianOwnsBookingValidator implements BookingTransitionValidator {
  validate({ actor, booking }: BookingTransitionContext): void {
    const applies = actor.role === Role.TECHNICIAN;
    const valid = booking.technician?.userId === actor.userId;

    if (applies && !valid) {
      throw new ForbiddenException({
        message: 'Technician cannot update an unassigned booking',
        errorCode: ErrorCodes.AUTH_FORBIDDEN,
      });
    }
  }
}

export class AssignedTechnicianRequiredValidator implements BookingTransitionValidator {
  validate({ booking }: BookingTransitionContext): void {
    if (!booking.technicianId) {
      throw new BadRequestException({
        message: 'Booking must have an assigned technician before this transition',
        errorCode: ErrorCodes.BOOKING_INVALID_STATUS,
      });
    }
  }
}

export class CancellationReasonValidator implements BookingTransitionValidator {
  validate({ dto }: BookingTransitionContext): void {
    if (dto.status === BookingStatus.CANCELLED && !dto.cancelReason?.trim()) {
      throw new BadRequestException({
        message: 'Cancellation reason is required',
        errorCode: ErrorCodes.BOOKING_INVALID_STATUS,
      });
    }
  }
}

export class FailureReasonValidator implements BookingTransitionValidator {
  validate({ dto }: BookingTransitionContext): void {
    if (dto.status === BookingStatus.FAILED && !dto.failureReason?.trim()) {
      throw new BadRequestException({
        message: 'Failure reason is required',
        errorCode: ErrorCodes.BOOKING_INVALID_STATUS,
      });
    }
  }
}

export class StartWorkOtpValidator implements BookingTransitionValidator {
  validate({ actor, booking, dto }: BookingTransitionContext): void {
    // Only TECHNICIAN role is subject to customer OTP verification (ADMIN can override in emergencies)
    if (actor.role !== Role.TECHNICIAN) {
      return;
    }

    // Only enforce when the booking has a startOtp configured
    if (!booking.startOtp) {
      return;
    }

    if (!dto.otp || !dto.otp.trim()) {
      throw new BadRequestException({
        message: 'Customer OTP is required to start the service',
        errorCode: ErrorCodes.BOOKING_OTP_REQUIRED,
      });
    }

    if (booking.startOtpAttempts >= 5) {
      throw new ForbiddenException({
        message: 'Maximum OTP verification attempts exceeded. Please contact support.',
        errorCode: ErrorCodes.BOOKING_OTP_MAX_ATTEMPTS,
      });
    }

    if (dto.otp.trim() !== booking.startOtp) {
      throw new BadRequestException({
        message: 'Invalid OTP. Please check with the customer.',
        errorCode: ErrorCodes.BOOKING_OTP_INVALID,
      });
    }
  }
}

export class CompletionOtpValidator implements BookingTransitionValidator {
  validate({ actor, booking, dto }: BookingTransitionContext): void {
    if (actor.role !== Role.TECHNICIAN) {
      return;
    }

    if (!booking.completionOtp) {
      return;
    }

    if (!dto.otp || !dto.otp.trim()) {
      throw new BadRequestException({
        message: 'Customer Completion OTP is required to finish the service',
        errorCode: ErrorCodes.BOOKING_OTP_REQUIRED,
      });
    }

    if (booking.completionOtpAttempts >= 5) {
      throw new ForbiddenException({
        message: 'Maximum Completion OTP verification attempts exceeded. Please contact support.',
        errorCode: ErrorCodes.BOOKING_OTP_MAX_ATTEMPTS,
      });
    }

    if (dto.otp.trim() !== booking.completionOtp) {
      throw new BadRequestException({
        message: 'Invalid Completion OTP. Please check with the customer.',
        errorCode: ErrorCodes.BOOKING_OTP_INVALID,
      });
    }
  }
}
