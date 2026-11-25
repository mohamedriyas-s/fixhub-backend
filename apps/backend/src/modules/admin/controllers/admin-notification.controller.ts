import { Controller, Delete, Get, Param, Patch, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiParam, ApiTags } from '@nestjs/swagger';
import { Role } from '@prisma/client';

import { Roles } from '../../../common/decorators/roles.decorator';
import { AdminNotificationService } from '../services/admin-notification.service';

@ApiTags('Admin')
@ApiBearerAuth()
@Controller('admin/notifications')
@Roles(Role.ADMIN)
export class AdminNotificationController {
  constructor(private readonly adminNotifService: AdminNotificationService) {}

  @Get()
  @ApiOperation({ summary: 'List recent admin notifications (newest first)' })
  async list(@Query('limit') limit?: string) {
    return this.adminNotifService.listRecent(limit ? Number(limit) : 50);
  }

  @Get('unread-count')
  @ApiOperation({ summary: 'Get unread admin notification count' })
  async unreadCount() {
    const count = await this.adminNotifService.getUnreadCount();
    return { count };
  }

  @Patch(':id/read')
  @ApiOperation({ summary: 'Mark a single admin notification as read' })
  @ApiParam({ name: 'id', description: 'AdminNotification id' })
  async markRead(@Param('id') id: string) {
    return this.adminNotifService.markRead(id);
  }

  @Patch('read-all')
  @ApiOperation({ summary: 'Mark all admin notifications as read' })
  async markAllRead() {
    return this.adminNotifService.markAllRead();
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Delete a single admin notification' })
  @ApiParam({ name: 'id', description: 'AdminNotification id' })
  async deleteOne(@Param('id') id: string) {
    return this.adminNotifService.deleteOne(id);
  }

  @Delete()
  @ApiOperation({ summary: 'Delete all admin notifications' })
  async deleteAll() {
    return this.adminNotifService.deleteAll();
  }
}
