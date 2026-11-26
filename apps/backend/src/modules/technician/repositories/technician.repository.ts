import { Injectable } from '@nestjs/common';

import { PrismaService } from '../../../common/database/prisma.service';

@Injectable()
export class TechnicianRepository {
  constructor(private readonly prisma: PrismaService) {}

  async findByUserId(userId: string) {
    return this.prisma.technician.findUnique({
      where: { userId },
      include: {
        user: { select: { id: true, phone: true, name: true, email: true, role: true } },
        serviceAreas: { include: { serviceArea: true } },
        specializations: {
          include: {
            subService: {
              include: { category: { select: { id: true, name: true, slug: true } } },
            },
          },
        },
        documents: {
          orderBy: { createdAt: 'desc' },
        },
      },
    });
  }

  async findTechnicianIdByUserId(userId: string) {
    const technician = await this.prisma.technician.findUnique({
      where: { userId },
      select: { id: true, verificationStatus: true },
    });
    return technician;
  }

  async updateProfile(userId: string, data: {
    name?: string;
    email?: string;
    phone?: string;
    profilePictureUrl?: string;
    latitude?: number;
    longitude?: number;
  }) {
    return this.prisma.$transaction(async (tx) => {
      // Update User-level fields
      if (data.name !== undefined || data.email !== undefined || data.phone !== undefined) {
        await tx.user.update({
          where: { id: userId },
          data: {
            ...(data.name !== undefined && { name: data.name }),
            ...(data.email !== undefined && { email: data.email }),
            ...(data.phone !== undefined && { phone: data.phone }),
          },
        });
      }

      // Update Technician-level fields
      const technicianUpdate: Record<string, unknown> = {};
      if (data.profilePictureUrl !== undefined) technicianUpdate.profilePictureUrl = data.profilePictureUrl;
      if (data.latitude !== undefined) technicianUpdate.latitude = data.latitude;
      if (data.longitude !== undefined) technicianUpdate.longitude = data.longitude;
      if (data.latitude !== undefined || data.longitude !== undefined) {
        technicianUpdate.lastLocationAt = new Date();
      }

      if (Object.keys(technicianUpdate).length > 0) {
        await tx.technician.update({
          where: { userId },
          data: technicianUpdate,
        });
      }

      if (data.latitude !== undefined && data.longitude !== undefined) {
        await tx.$executeRaw`
          UPDATE technicians
          SET location = ST_SetSRID(ST_MakePoint(${data.longitude}::float, ${data.latitude}::float), 4326)
          WHERE user_id = ${userId}::uuid
        `;
      }

      // Return full profile
      return tx.technician.findUnique({
        where: { userId },
        include: {
          user: { select: { id: true, phone: true, name: true, email: true, role: true } },
          serviceAreas: { include: { serviceArea: true } },
          specializations: {
            include: {
              subService: {
                include: { category: { select: { id: true, name: true, slug: true } } },
              },
            },
          },
          documents: { orderBy: { createdAt: 'desc' } },
        },
      });
    });
  }

  async updateAvailability(userId: string, isAvailable: boolean, latitude?: number, longitude?: number) {
    const technician = await this.prisma.technician.update({
      where: { userId },
      data: {
        isAvailable,
        ...(latitude !== undefined && { latitude }),
        ...(longitude !== undefined && { longitude }),
        ...((latitude !== undefined || longitude !== undefined) && { lastLocationAt: new Date() }),
      },
      include: {
        user: { select: { id: true, phone: true, name: true, email: true, role: true } },
      },
    });

    if (latitude !== undefined && longitude !== undefined) {
      await this.prisma.$executeRaw`
        UPDATE technicians
        SET location = ST_SetSRID(ST_MakePoint(${longitude}::float, ${latitude}::float), 4326)
        WHERE user_id = ${userId}::uuid
      `;
    }

    return technician;
  }

  async updateLocation(userId: string, latitude: number, longitude: number) {
    const technician = await this.prisma.technician.update({
      where: { userId },
      data: {
        latitude,
        longitude,
        lastLocationAt: new Date(),
      },
      select: {
        id: true,
        latitude: true,
        longitude: true,
        lastLocationAt: true,
      },
    });

    // Update PostGIS location field
    await this.prisma.$executeRaw`
      UPDATE technicians
      SET location = ST_SetSRID(ST_MakePoint(${longitude}::float, ${latitude}::float), 4326)
      WHERE user_id = ${userId}::uuid
    `;

    return technician;
  }

  async findNearbyTechnicians(latitude: number, longitude: number, radiusInMeters: number = 5000) {
    // PostGIS raw SQL for radius search (distance in meters)
    const technicians = await this.prisma.$queryRaw<any[]>`
      SELECT 
        t.id, 
        t.user_id as "userId",
        t.latitude, 
        t.longitude,
        t.is_available as "isAvailable",
        ST_DistanceSphere(t.location, ST_MakePoint(${longitude}::float, ${latitude}::float)) as distance
      FROM technicians t
      INNER JOIN users u ON t.user_id = u.id
      WHERE t.deleted_at IS NULL
        AND u.is_active = true
        AND t.verification_status = 'VERIFIED'
        AND ST_DWithin(t.location, ST_MakePoint(${longitude}::float, ${latitude}::float), ${radiusInMeters})
      ORDER BY distance ASC
      LIMIT 50
    `;
    return technicians;
  }
}
