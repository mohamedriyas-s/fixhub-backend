import { Body, Controller, Delete, Get, Param, Patch, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiParam, ApiResponse, ApiTags } from '@nestjs/swagger';
import { Role } from '@prisma/client';

import { Roles } from '../../../common/decorators/roles.decorator';
import { PaginationDto } from '../../../common/dto/pagination.dto';
import { CreateServiceAreaDto, ServiceAreaQueryDto, UpdateServiceAreaDto } from '../dto';
import { ServiceAreaService } from '../services/service-area.service';
import { ServiceAreaCacheService } from '../services/service-area-cache.service';

@ApiTags('Admin Service Areas')
@ApiBearerAuth()
@Roles(Role.ADMIN)
@Controller('admin/service-areas')
export class AdminServiceAreaController {
  constructor(
    private readonly serviceAreaService: ServiceAreaService,
    private readonly cacheService: ServiceAreaCacheService,
  ) {}

  @Get()
  @ApiOperation({ summary: 'List all service areas for admin' })
  list(@Query() query: ServiceAreaQueryDto) {
    return this.serviceAreaService.list(query, false);
  }

  @Get('coverage-requests')
  @ApiOperation({ summary: 'List customer coverage requests' })
  listCoverageRequests(@Query() query: PaginationDto) {
    return this.serviceAreaService.listCoverageRequests(query);
  }

  @Patch('coverage-requests/:id/handled')
  @ApiOperation({ summary: 'Mark a coverage request as handled' })
  @ApiParam({ name: 'id', description: 'Coverage request id' })
  markCoverageRequestHandled(@Param('id') id: string) {
    return this.serviceAreaService.markCoverageRequestHandled(id);
  }

  @Post()
  @ApiOperation({ summary: 'Create service area' })
  @ApiResponse({ status: 201, description: 'Service area created' })
  async create(@Body() dto: CreateServiceAreaDto) {
    const result = await this.serviceAreaService.create(dto);
    await this.cacheService.invalidate();
    return result;
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Update service area' })
  @ApiParam({ name: 'id', description: 'Service area id' })
  @ApiResponse({ status: 200, description: 'Service area updated' })
  async update(@Param('id') id: string, @Body() dto: UpdateServiceAreaDto) {
    const result = await this.serviceAreaService.update(id, dto);
    await this.cacheService.invalidate();
    return result;
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Soft delete service area' })
  @ApiParam({ name: 'id', description: 'Service area id' })
  @ApiResponse({ status: 200, description: 'Service area deleted' })
  async delete(@Param('id') id: string) {
    const result = await this.serviceAreaService.delete(id);
    await this.cacheService.invalidate();
    return result;
  }
}
