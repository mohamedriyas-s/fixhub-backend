import { Injectable } from '@nestjs/common';
import { Prisma, VerificationStatus } from '@prisma/client';

import { PrismaService } from '../../../common/database/prisma.service';
import { CustomerQueryDto, PaymentQueryDto, TechnicianQueryDto } from '../dto/admin.dto';

@Injectable()
export class AdminRepository {
  constructor(private readonly prisma: PrismaService) {}

  async getDashboardStats() {
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 29);
    thirtyDaysAgo.setHours(0, 0, 0, 0);

    const firstDayOfMonth = new Date();
    firstDayOfMonth.setDate(1);
    firstDayOfMonth.setHours(0, 0, 0, 0);

    const [
      totalBookings,
      totalCustomers,
      totalTechnicians,
      activeBookings,
      recentBookings,
      revenueRaw,
      categoryRaw,
      timelineRaw,
    ] = await Promise.all([
      this.prisma.booking.count(),
      this.prisma.customer.count(),
      this.prisma.technician.count(),
      this.prisma.booking.count({
        where: {
          status: {
            in: [
              'PENDING_PAYMENT',
              'CONFIRMED',
              'ASSIGNED',
              'ACCEPTED',
              'EN_ROUTE',
              'ARRIVED',
              'IN_PROGRESS',
              'PRICE_REVISION_PENDING',
            ],
          },
        },
      }),
      this.prisma.booking.findMany({
        take: 5,
        orderBy: { createdAt: 'desc' },
        include: {
          customer: {
            include: { user: { select: { id: true, name: true, phone: true, email: true } } },
          },
          technician: {
            include: { user: { select: { id: true, name: true, phone: true, email: true } } },
          },
          subService: {
            select: {
              id: true,
              name: true,
              basePrice: true,
              estimatedDurationMins: true,
              category: { select: { id: true, name: true, slug: true } },
            },
          },
          address: { select: { id: true, label: true, city: true, state: true, pincode: true } },
        },
      }),
      this.prisma.booking.findMany({
        where: { createdAt: { gte: thirtyDaysAgo } },
        select: { createdAt: true, totalAmount: true },
      }),
      this.prisma.booking.findMany({
        where: { createdAt: { gte: firstDayOfMonth } },
        select: { subService: { select: { category: { select: { name: true } } } } },
      }),
      this.prisma.bookingTimeline.findMany({
        take: 5,
        orderBy: { createdAt: 'desc' },
        include: {
          booking: { select: { bookingNumber: true, subService: { select: { name: true } } } },
        },
      }),
    ]);

    // 1. Process Revenue Data
    const revenueMap = new Map<string, { revenue: number; bookings: number }>();

    // Initialize last 30 days
    for (let i = 29; i >= 0; i--) {
      const d = new Date();
      d.setDate(d.getDate() - i);
      const key = d.toLocaleDateString('en-IN', { day: '2-digit', month: 'short' });
      revenueMap.set(key, { revenue: 0, bookings: 0 });
    }

    for (const b of revenueRaw) {
      const key = b.createdAt.toLocaleDateString('en-IN', { day: '2-digit', month: 'short' });
      if (revenueMap.has(key)) {
        const current = revenueMap.get(key)!;
        current.bookings += 1;
        current.revenue += Number(b.totalAmount || 0);
      }
    }

    const revenueData = Array.from(revenueMap.entries()).map(([date, data]) => ({
      date,
      revenue: data.revenue,
      bookings: data.bookings,
    }));

    // 2. Process Category Data
    const categoryMap = new Map<string, number>();
    for (const b of categoryRaw) {
      const catName = b.subService?.category?.name || 'Unknown';
      categoryMap.set(catName, (categoryMap.get(catName) || 0) + 1);
    }

    // Modern color palette for categories
    const colors = ['#6F7F5F', '#3B82F6', '#F59E0B', '#8B5CF6', '#22C55E', '#EC4899', '#06B6D4'];
    const categoryData = Array.from(categoryMap.entries())
      .map(([name, bookings], i) => ({
        name,
        bookings,
        color: colors[i % colors.length],
      }))
      .sort((a, b) => b.bookings - a.bookings);

    // 3. Process Recent Activity
    const recentActivity = timelineRaw.map((t) => ({
      title: `Booking ${t.status.toLowerCase()}`,
      description: `${t.booking.bookingNumber} — ${t.booking.subService?.name || 'Service'}`,
      time: t.createdAt.toISOString(),
    }));

    return {
      totalBookings,
      totalCustomers,
      totalTechnicians,
      activeBookings,
      recentBookings,
      revenueData,
      categoryData,
      recentActivity,
    };
  }

  async listCustomers(query: CustomerQueryDto) {
    const where: Prisma.CustomerWhereInput = {
      ...(query.isActive !== undefined && { user: { isActive: query.isActive } }),
      ...(query.search && {
        user: {
          OR: [
            { name: { contains: query.search, mode: 'insensitive' } },
            { email: { contains: query.search, mode: 'insensitive' } },
            { phone: { contains: query.search } },
          ],
        },
      }),
    };

    const sortBy = this.customerSortField(query.sortBy);
    const [items, total] = await this.prisma.$transaction([
      this.prisma.customer.findMany({
        where,
        skip: query.skip,
        take: query.limit,
        orderBy:
          sortBy === 'createdAt' || sortBy === 'updatedAt'
            ? { [sortBy]: query.sortOrder ?? 'desc' }
            : { user: { [sortBy]: query.sortOrder ?? 'asc' } },
        include: {
          user: {
            select: {
              id: true,
              name: true,
              email: true,
              phone: true,
              isActive: true,
              createdAt: true,
            },
          },
          _count: { select: { addresses: true, bookings: true } },
        },
      }),
      this.prisma.customer.count({ where }),
    ]);

    return this.paginate(items, total, query);
  }

  async getCustomerDetails(id: string) {
    return this.prisma.customer.findUnique({
      where: { id },
      include: {
        user: {
          select: {
            id: true,
            name: true,
            email: true,
            phone: true,
            isActive: true,
            createdAt: true,
            updatedAt: true,
          },
        },
        addresses: true,
        bookings: {
          take: 10,
          orderBy: { createdAt: 'desc' },
          include: { subService: { include: { category: true } } },
        },
        _count: { select: { bookings: true } },
      },
    });
  }

  async listTechnicians(query: TechnicianQueryDto) {
    const where: Prisma.TechnicianWhereInput = {
      ...(query.verificationStatus && { verificationStatus: query.verificationStatus }),
      ...(query.isAvailable !== undefined && { isAvailable: query.isAvailable }),
      ...(query.isActive !== undefined && { user: { isActive: query.isActive } }),
      ...(query.search && {
        user: {
          OR: [
            { name: { contains: query.search, mode: 'insensitive' } },
            { email: { contains: query.search, mode: 'insensitive' } },
            { phone: { contains: query.search } },
          ],
        },
      }),
    };

    const sortBy = this.technicianSortField(query.sortBy);

    // Sort logic for nested user fields vs technician fields
    let orderBy: Prisma.TechnicianOrderByWithRelationInput = {};
    if (sortBy === 'name' || sortBy === 'email') {
      orderBy = { user: { [sortBy]: query.sortOrder ?? 'asc' } };
    } else {
      orderBy = { [sortBy]: query.sortOrder ?? 'desc' };
    }

    const [items, total] = await this.prisma.$transaction([
      this.prisma.technician.findMany({
        where,
        skip: query.skip,
        take: query.limit,
        orderBy,
        include: {
          user: {
            select: {
              id: true,
              name: true,
              email: true,
              phone: true,
              isActive: true,
              createdAt: true,
            },
          },
          _count: { select: { bookings: true } },
        },
      }),
      this.prisma.technician.count({ where }),
    ]);

    return this.paginate(items, total, query);
  }

  async getTechnicianDetails(id: string) {
    return this.prisma.technician.findUnique({
      where: { id },
      include: {
        user: {
          select: {
            id: true,
            name: true,
            email: true,
            phone: true,
            isActive: true,
            createdAt: true,
            updatedAt: true,
          },
        },
        specializations: { include: { subService: { include: { category: true } } } },
        serviceAreas: { include: { serviceArea: true } },
        documents: true,
        _count: { select: { bookings: true, reviews: true } },
      },
    });
  }

  async updateUserStatus(userId: string, isActive: boolean) {
    return this.prisma.user.update({
      where: { id: userId },
      data: { isActive },
      select: { id: true, isActive: true, role: true },
    });
  }

  async verifyTechnician(id: string, status: VerificationStatus, rejectionNote?: string) {
    return this.prisma.technician.update({
      where: { id },
      data: {
        verificationStatus: status,
        ...(status === VerificationStatus.REJECTED && rejectionNote
          ? { rejectionNote }
          : { rejectionNote: null }),
        ...(status === VerificationStatus.VERIFIED && { isAvailable: false }), // Reset availability on status change
      },
      include: {
        user: { select: { id: true, name: true, phone: true, email: true, isActive: true } },
      },
    });
  }

  async listPayments(query: PaymentQueryDto) {
    const where: Prisma.PaymentWhereInput = {
      ...(query.status && { status: query.status }),
    };

    const sortBy = query.sortBy === 'amount' ? 'amount' : 'createdAt';

    const [items, total] = await this.prisma.$transaction([
      this.prisma.payment.findMany({
        where,
        skip: query.skip,
        take: query.limit,
        orderBy: { [sortBy]: query.sortOrder ?? 'desc' },
        include: {
          booking: {
            select: {
              bookingNumber: true,
              customer: {
                select: {
                  user: {
                    select: { name: true, phone: true, email: true },
                  },
                },
              },
            },
          },
        },
      }),
      this.prisma.payment.count({ where }),
    ]);

    return this.paginate(items, total, query);
  }

  // ─── Technician CRUD ────────────────────────────────────

  async createTechnician(dto: { name: string; phone?: string; email?: string }) {
    const normalizedEmail = dto.email?.trim().toLowerCase() || undefined;
    return this.prisma.$transaction(async (tx) => {
      const user = await tx.user.create({
        data: {
          name: dto.name,
          phone: dto.phone?.trim() || null,
          email: normalizedEmail,
          loginEmail: normalizedEmail,
          role: 'TECHNICIAN',
        },
      });
      const technician = await tx.technician.create({
        data: { userId: user.id },
        include: {
          user: {
            select: {
              id: true,
              name: true,
              email: true,
              phone: true,
              isActive: true,
              createdAt: true,
            },
          },
        },
      });
      return technician;
    });
  }

  async updateTechnicianDetails(id: string, dto: { name?: string; email?: string }) {
    const tech = await this.prisma.technician.findUnique({
      where: { id },
      select: { userId: true },
    });
    if (!tech) return null;
    return this.prisma.user.update({
      where: { id: tech.userId },
      data: { ...dto },
      select: { id: true, name: true, email: true, phone: true, isActive: true },
    });
  }

  async addSpecialization(technicianId: string, subServiceId: string) {
    return this.prisma.technicianSpecialization.upsert({
      where: { technicianId_subServiceId: { technicianId, subServiceId } },
      create: { technicianId, subServiceId },
      update: {},
    });
  }

  async removeSpecialization(technicianId: string, subServiceId: string) {
    return this.prisma.technicianSpecialization.deleteMany({
      where: { technicianId, subServiceId },
    });
  }

  async addServiceArea(technicianId: string, serviceAreaId: string) {
    return this.prisma.technicianServiceArea.upsert({
      where: { technicianId_serviceAreaId: { technicianId, serviceAreaId } },
      create: { technicianId, serviceAreaId },
      update: {},
    });
  }

  async removeServiceArea(technicianId: string, serviceAreaId: string) {
    return this.prisma.technicianServiceArea.deleteMany({
      where: { technicianId, serviceAreaId },
    });
  }

  async getEligibleTechnicians(subServiceId: string, pincode: string) {
    return this.prisma.technician.findMany({
      where: {
        deletedAt: null,
        verificationStatus: VerificationStatus.VERIFIED,
        user: { isActive: true, deletedAt: null },
        specializations: { some: { subServiceId } },
        serviceAreas: { some: { serviceArea: { pincode, isActive: true, deletedAt: null } } },
      },
      include: {
        user: { select: { id: true, name: true, phone: true, email: true, isActive: true } },
        specializations: { include: { subService: { include: { category: true } } } },
        serviceAreas: { include: { serviceArea: true } },
      },
      take: 50,
    });
  }

  // ─── Customer CRUD ──────────────────────────────────────

  async createCustomer(dto: { name: string; phone?: string; email?: string }) {
    const normalizedEmail = dto.email?.trim().toLowerCase() || undefined;
    return this.prisma.$transaction(async (tx) => {
      const user = await tx.user.create({
        data: {
          name: dto.name,
          phone: dto.phone?.trim() || null,
          email: normalizedEmail,
          loginEmail: normalizedEmail,
          role: 'CUSTOMER',
        },
      });
      const customer = await tx.customer.create({
        data: { userId: user.id },
        include: {
          user: {
            select: {
              id: true,
              name: true,
              email: true,
              phone: true,
              isActive: true,
              createdAt: true,
            },
          },
        },
      });
      return customer;
    });
  }

  async updateCustomerDetails(id: string, dto: { name?: string; email?: string }) {
    const customer = await this.prisma.customer.findUnique({
      where: { id },
      select: { userId: true },
    });
    if (!customer) return null;
    return this.prisma.user.update({
      where: { id: customer.userId },
      data: { ...dto },
      select: { id: true, name: true, email: true, phone: true, isActive: true },
    });
  }

  // ─── Admin Booking CRUD ─────────────────────────────────

  async listBookings(query: any) {
    const page = Number(query.page) || 1;
    const limit = Number(query.limit) || 20;
    const skip = (page - 1) * limit;

    const where: any = {};
    if (query.status) where.status = query.status;
    if (query.search) {
      where.OR = [
        { bookingNumber: { contains: query.search, mode: 'insensitive' } },
        { customer: { user: { name: { contains: query.search, mode: 'insensitive' } } } },
        { technician: { user: { name: { contains: query.search, mode: 'insensitive' } } } },
      ];
    }

    const [items, total] = await Promise.all([
      this.prisma.booking.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          customer: { select: { user: { select: { name: true, phone: true, email: true } } } },
          technician: { select: { user: { select: { name: true, phone: true, email: true } } } },
          subService: { select: { name: true } },
        },
      }),
      this.prisma.booking.count({ where }),
    ]);

    return {
      items,
      meta: {
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  async getBookingDetails(id: string) {
    return this.prisma.booking.findUnique({
      where: { id },
      include: {
        customer: { include: { user: true } },
        technician: { include: { user: true } },
        subService: { include: { category: true } },
        address: true,
        timeline: { orderBy: { createdAt: 'desc' } },
        payment: true,
      },
    });
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
    const count = await this.prisma.booking.count();
    const date = new Date().toISOString().split('T')[0].replace(/-/g, '');
    const bookingNumber = `FH-${date}-${String(count + 1).padStart(4, '0')}`;

    return this.prisma.booking.create({
      data: {
        bookingNumber,
        customerId: dto.customerId,
        subServiceId: dto.subServiceId,
        addressId: dto.addressId,
        technicianId: dto.technicianId,
        scheduledDate: new Date(dto.scheduledDate),
        scheduledSlot: dto.scheduledSlot,
        description: dto.description,
        totalAmount: dto.totalAmount,
        status: 'CONFIRMED',
        createdBy: dto.adminUserId,
        updatedBy: dto.adminUserId,
      },
      include: {
        customer: {
          include: { user: { select: { id: true, name: true, phone: true, email: true } } },
        },
        subService: { include: { category: true } },
        address: true,
      },
    });
  }

  async softDeleteBooking(id: string, reason: string, adminUserId: string) {
    const updated = await this.prisma.booking.update({
      where: { id },
      data: {
        status: 'CANCELLED',
        cancelledAt: new Date(),
        cancelledBy: 'ADMIN',
        cancelReason: reason,
        archivedAt: new Date(), // Will be purged by background job after 90 days
        updatedBy: adminUserId,
      },
    });
    return updated;
  }

  async cancelBooking(id: string, reason: string, adminUserId: string) {
    const updated = await this.prisma.booking.update({
      where: { id },
      data: {
        status: 'CANCELLED',
        cancelledAt: new Date(),
        cancelledBy: 'ADMIN',
        cancelReason: reason,
        updatedBy: adminUserId,
      },
    });
    return updated;
  }

  // ─── Pricing CRUD ───────────────────────────────────────

  async listPricingRules() {
    return this.prisma.pricingRule.findMany({ orderBy: { createdAt: 'asc' } });
  }

  async createPricingRule(
    dto: {
      categoryId?: string;
      label: string;
      baseFee: number;
      taxPercent: number;
      cancellationFeePercent?: number;
      cancellationWindowMins?: number;
    },
    adminUserId: string,
  ) {
    return this.prisma.pricingRule.create({
      data: {
        categoryId: dto.categoryId,
        label: dto.label,
        baseFee: dto.baseFee,
        taxPercent: dto.taxPercent,
        cancellationFeePercent: dto.cancellationFeePercent ?? 10,
        cancellationWindowMins: dto.cancellationWindowMins ?? 60,
        updatedBy: adminUserId,
      },
    });
  }

  async updatePricingRule(
    id: string,
    dto: {
      label?: string;
      baseFee?: number;
      taxPercent?: number;
      cancellationFeePercent?: number;
      cancellationWindowMins?: number;
      isActive?: boolean;
    },
    adminUserId: string,
  ) {
    return this.prisma.pricingRule.update({
      where: { id },
      data: { ...dto, updatedBy: adminUserId },
    });
  }

  async deletePricingRule(id: string) {
    return this.prisma.pricingRule.delete({ where: { id } });
  }

  // ─── Coupons CRUD ───────────────────────────────────────

  async listCoupons(query: { isActive?: boolean; page?: number; limit?: number }) {
    const page = query.page ?? 1;
    const limit = query.limit ?? 20;
    const where: Prisma.CouponWhereInput = {
      ...(query.isActive !== undefined && { isActive: query.isActive }),
    };

    const [items, total] = await this.prisma.$transaction([
      this.prisma.coupon.findMany({
        where,
        skip: (page - 1) * limit,
        take: limit,
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.coupon.count({ where }),
    ]);

    return this.paginate(items, total, { page, limit });
  }

  async createCoupon(
    dto: {
      code: string;
      description?: string;
      type: 'PERCENTAGE' | 'FLAT';
      value: number;
      maxDiscountAmount?: number;
      minOrderAmount?: number;
      firstBookingOnly?: boolean;
      maxUses?: number;
      expiresAt?: string;
      categoryId?: string;
    },
    adminUserId: string,
  ) {
    return this.prisma.coupon.create({
      data: {
        code: dto.code.toUpperCase(),
        description: dto.description,
        type: dto.type as any,
        value: dto.value,
        maxDiscountAmount: dto.maxDiscountAmount,
        minOrderAmount: dto.minOrderAmount,
        firstBookingOnly: dto.firstBookingOnly ?? false,
        maxUses: dto.maxUses,
        expiresAt: dto.expiresAt ? new Date(dto.expiresAt) : undefined,
        categoryId: dto.categoryId,
        createdBy: adminUserId,
      },
    });
  }

  async updateCoupon(
    id: string,
    dto: {
      description?: string;
      maxUses?: number;
      expiresAt?: string;
      isActive?: boolean;
    },
  ) {
    return this.prisma.coupon.update({
      where: { id },
      data: {
        ...dto,
        expiresAt: dto.expiresAt ? new Date(dto.expiresAt) : undefined,
      },
    });
  }

  async deleteCoupon(id: string) {
    return this.prisma.coupon.delete({ where: { id } });
  }

  private customerSortField(sortBy?: string) {
    const allowed = new Set(['name', 'email', 'createdAt', 'updatedAt']);
    return allowed.has(sortBy ?? '') ? sortBy! : 'createdAt';
  }

  private technicianSortField(sortBy?: string) {
    const allowed = new Set([
      'name',
      'email',
      'createdAt',
      'rating',
      'totalJobs',
      'verificationStatus',
    ]);
    return allowed.has(sortBy ?? '') ? sortBy! : 'createdAt';
  }

  private paginate<T>(items: T[], total: number, query: any) {
    const page = query.page ?? 1;
    const limit = query.limit ?? 10;
    return {
      items,
      meta: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
        hasNextPage: page * limit < total,
        hasPreviousPage: page > 1,
      },
    };
  }
}
