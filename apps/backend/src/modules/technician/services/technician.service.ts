import { ErrorCodes } from '@fixhub/shared';
import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
  Optional,
} from '@nestjs/common';
import { EventEmitter2 } from '@nestjs/event-emitter';

import { PrismaService } from '../../../common/database/prisma.service';
import { TrackingGateway } from '../../tracking/tracking.gateway';
import { UpdateAvailabilityDto, UpdateLocationDto, UpdateProfileDto } from '../dto';
import { TechnicianRepository } from '../repositories/technician.repository';
import { TechnicianHeartbeatService } from './technician-heartbeat.service';

@Injectable()
export class TechnicianService {
  private readonly logger = new Logger(TechnicianService.name);

  constructor(
    private readonly technicianRepository: TechnicianRepository,
    private readonly prisma: PrismaService,
    private readonly eventEmitter: EventEmitter2,
    private readonly heartbeatService: TechnicianHeartbeatService,
    @Optional() private readonly trackingGateway: TrackingGateway,
  ) {}

  async getProfile(userId: string) {
    const technician = await this.technicianRepository.findByUserId(userId);
    if (!technician) {
      throw new NotFoundException({
        message: 'Technician not found',
        errorCode: ErrorCodes.TECHNICIAN_NOT_FOUND,
      });
    }

    // If technician is currently marked available, refresh heartbeat on active read
    if (technician.isAvailable) {
      await this.heartbeatService.ping(technician.id);
    }

    return technician;
  }

  async updateProfile(userId: string, dto: UpdateProfileDto) {
    // Verify technician exists
    await this.resolveTechnicianId(userId);

    const result = await this.technicianRepository.updateProfile(userId, {
      name: dto.name,
      email: dto.email,
      profilePictureUrl: dto.profilePictureUrl,
      latitude: dto.latitude,
      longitude: dto.longitude,
    });
    this.eventEmitter.emit('technician.updated', userId);
    return result;
  }

  async updateAvailability(userId: string, dto: UpdateAvailabilityDto) {
    const technician = await this.technicianRepository.findTechnicianIdByUserId(userId);
    if (!technician) {
      throw new NotFoundException({
        message: 'Technician not found',
        errorCode: ErrorCodes.TECHNICIAN_NOT_FOUND,
      });
    }

    // Only verified technicians can go available
    if (dto.isAvailable && technician.verificationStatus !== 'VERIFIED') {
      throw new BadRequestException({
        message: 'Technician must be verified before going available',
        errorCode: ErrorCodes.TECHNICIAN_NOT_VERIFIED,
      });
    }

    const result = await this.technicianRepository.updateAvailability(
      userId,
      dto.isAvailable,
      dto.latitude,
      dto.longitude,
    );

    if (dto.isAvailable) {
      await this.heartbeatService.ping(technician.id);
    }

    this.eventEmitter.emit('technician.availability_changed', technician.id);
    return result;
  }

  async updateLocation(userId: string, dto: UpdateLocationDto) {
    const technicianId = await this.resolveTechnicianId(userId);
    const updated = await this.technicianRepository.updateLocation(
      userId,
      dto.latitude,
      dto.longitude,
    );

    // Update heartbeat TTL
    await this.heartbeatService.ping(technicianId);

    // Broadcast to any customer currently watching this technician's active booking
    if (this.trackingGateway) {
      const activeBookingId = await this.findActiveBookingId(userId);
      if (activeBookingId) {
        this.trackingGateway.broadcastLocationUpdate(activeBookingId, {
          latitude: dto.latitude,
          longitude: dto.longitude,
          lastLocationAt: new Date(),
        });
      }
    }

    return updated;
  }

  /**
   * Resolve technician ID from user ID or throw 404.
   * Used by other services to get the technician record ID.
   */
  async resolveTechnicianId(userId: string): Promise<string> {
    const technician = await this.technicianRepository.findTechnicianIdByUserId(userId);
    if (!technician) {
      throw new NotFoundException({
        message: 'Technician not found',
        errorCode: ErrorCodes.TECHNICIAN_NOT_FOUND,
      });
    }
    return technician.id;
  }

  // ─── Private helpers ─────────────────────────────────────────────────────

  /**
   * Finds the booking ID of the technician's current active job (EN_ROUTE or ARRIVED).
   * Used to know which booking room to broadcast location updates to.
   */
  private async findActiveBookingId(userId: string): Promise<string | null> {
    const booking = await this.prisma.booking.findFirst({
      where: {
        technician: { userId },
        status: { in: ['EN_ROUTE', 'ARRIVED'] },
      },
      select: { id: true },
      orderBy: { updatedAt: 'desc' },
    });
    return booking?.id ?? null;
  }
}
