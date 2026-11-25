import { Injectable, Logger, Optional } from '@nestjs/common';

import { PrismaService } from '../../../common/database/prisma.service';
import { AdminNotificationsGateway } from '../gateways/admin-notifications.gateway';

export const AdminNotifType = {
  TECHNICIAN_ASSIGNED: 'TECHNICIAN_ASSIGNED',
  JOB_DECLINED: 'JOB_DECLINED',
  NEW_BOOKING: 'NEW_BOOKING',
  BOOKING_CANCELLED: 'BOOKING_CANCELLED',
  PAYMENT_CAPTURED: 'PAYMENT_CAPTURED',
  REFUND_PROCESSED: 'REFUND_PROCESSED',
  VERIFICATION_SUBMITTED: 'VERIFICATION_SUBMITTED',
  TECHNICIAN_VERIFIED: 'TECHNICIAN_VERIFIED',
  TECHNICIAN_REJECTED: 'TECHNICIAN_REJECTED',
  SERVICE_AREA_REQUEST: 'SERVICE_AREA_REQUEST',
  SYSTEM: 'SYSTEM',
} as const;

export type AdminNotifTypeValue = (typeof AdminNotifType)[keyof typeof AdminNotifType];

@Injectable()
export class AdminNotificationService {
  private readonly logger = new Logger(AdminNotificationService.name);

  constructor(
    private readonly prisma: PrismaService,
    @Optional() private readonly gateway: AdminNotificationsGateway,
  ) {}

  /**
   * Persist an admin notification to DB and broadcast it over WebSocket.
   * Fire-and-forget friendly — never throws.
   */
  async createAndBroadcast(
    type: AdminNotifTypeValue,
    title: string,
    body: string,
    metadata?: Record<string, unknown>,
  ): Promise<void> {
    try {
      const notification = await this.prisma.adminNotification.create({
        data: {
          type,
          title,
          body,
          metadata: metadata ? JSON.parse(JSON.stringify(metadata)) : undefined,
        },
      });

      // Real-time push — gateway may not be available in test environments
      if (this.gateway) {
        this.gateway.broadcastToAdmin('notification:new', {
          id: notification.id,
          type: notification.type,
          title: notification.title,
          body: notification.body,
          metadata: notification.metadata,
          isRead: notification.isRead,
          createdAt: notification.createdAt,
        });
      }
    } catch (err: any) {
      this.logger.error(`Failed to create admin notification [${type}]: ${err.message}`);
    }
  }

  /** Returns the last N admin notifications (default 50), newest first. */
  async listRecent(limit = 50) {
    return this.prisma.adminNotification.findMany({
      orderBy: { createdAt: 'desc' },
      take: limit,
    });
  }

  /** Unread count for the badge. */
  async getUnreadCount(): Promise<number> {
    return this.prisma.adminNotification.count({ where: { isRead: false } });
  }

  /** Mark a single notification as read and broadcast the update. */
  async markRead(id: string) {
    const updated = await this.prisma.adminNotification.update({
      where: { id },
      data: { isRead: true },
    });

    if (this.gateway) {
      this.gateway.broadcastToAdmin('notification:read', { id });
    }

    return updated;
  }

  /** Mark all notifications as read. */
  async markAllRead() {
    await this.prisma.adminNotification.updateMany({
      where: { isRead: false },
      data: { isRead: true },
    });

    if (this.gateway) {
      this.gateway.broadcastToAdmin('notification:all_read', {});
    }

    return { success: true };
  }

  /** Delete a single admin notification and broadcast the update. */
  async deleteOne(id: string) {
    await this.prisma.adminNotification.deleteMany({ where: { id } });

    if (this.gateway) {
      this.gateway.broadcastToAdmin('notification:deleted', { id });
    }

    return { success: true, id };
  }

  /** Delete all admin notifications and broadcast the update. */
  async deleteAll() {
    await this.prisma.adminNotification.deleteMany({});

    if (this.gateway) {
      this.gateway.broadcastToAdmin('notification:all_deleted', {});
    }

    return { success: true };
  }
}
