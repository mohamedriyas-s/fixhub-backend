import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';

import type {
  PaginatedResponse,
  Technician,
  TechnicianQueryParams,
  VerificationStatus,
} from '@/lib/types';

import { apiClient } from '../client';
import { endpoints } from '../endpoints';

export function useTechnicians(params?: TechnicianQueryParams) {
  return useQuery({
    queryKey: ['technicians', params],
    queryFn: async () => {
      const { data } = await apiClient.get<PaginatedResponse<Technician>>(
        endpoints.admin.technicians,
        { params },
      );
      return data.data;
    },
  });
}

export function useTechnician(id: string) {
  return useQuery({
    queryKey: ['technician', id],
    queryFn: async () => {
      const { data } = await apiClient.get<{ data: Technician }>(endpoints.admin.technician(id));
      return data.data;
    },
    enabled: !!id,
  });
}

export function useUpdateTechnicianStatus() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async ({ userId, isActive }: { userId: string; isActive: boolean }) => {
      const { data } = await apiClient.patch(endpoints.admin.technicianStatus(userId), {
        isActive,
      });
      return data;
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['technicians'] });
    },
  });
}

export function useVerifyTechnician() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async ({
      id,
      status,
      rejectionNote,
    }: {
      id: string;
      status: VerificationStatus;
      rejectionNote?: string;
    }) => {
      const { data } = await apiClient.patch(endpoints.admin.technicianVerify(id), {
        status,
        rejectionNote,
      });
      return data;
    },
    onSuccess: (_, { id }) => {
      qc.invalidateQueries({ queryKey: ['technicians'] });
      qc.invalidateQueries({ queryKey: ['technician', id] });
    },
  });
}

export function useEligibleTechnicians(subServiceId?: string, pincode?: string) {
  return useQuery({
    queryKey: ['technicians', 'eligible', subServiceId, pincode],
    queryFn: async () => {
      const { data } = await apiClient.get<{ data: Technician[] }>(
        endpoints.admin.eligibleTechnicians,
        { params: { subServiceId, pincode } },
      );
      return data.data;
    },
    enabled: !!subServiceId && !!pincode,
  });
}

export function useCreateTechnician() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (payload: { name: string; phone?: string; email?: string }) => {
      const { data } = await apiClient.post(endpoints.admin.technicians, payload);
      return data;
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['technicians'] });
    },
  });
}

export function useUpdateTechnicianDetails() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async ({
      id,
      payload,
    }: {
      id: string;
      payload: { name?: string; email?: string };
    }) => {
      const { data } = await apiClient.patch(endpoints.admin.technicianDetails(id), payload);
      return data;
    },
    onSuccess: (_, { id }) => {
      qc.invalidateQueries({ queryKey: ['technicians'] });
      qc.invalidateQueries({ queryKey: ['technician', id] });
    },
  });
}

export function useAddSpecialization() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async ({
      technicianId,
      subServiceId,
    }: {
      technicianId: string;
      subServiceId: string;
    }) => {
      const { data } = await apiClient.post(
        endpoints.admin.technicianSpecializations(technicianId),
        { subServiceId },
      );
      return data;
    },
    onSuccess: (_, { technicianId }) => {
      qc.invalidateQueries({ queryKey: ['technician', technicianId] });
    },
  });
}

export function useRemoveSpecialization() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async ({
      technicianId,
      subServiceId,
    }: {
      technicianId: string;
      subServiceId: string;
    }) => {
      const { data } = await apiClient.delete(
        endpoints.admin.technicianSpecialization(technicianId, subServiceId),
      );
      return data;
    },
    onSuccess: (_, { technicianId }) => {
      qc.invalidateQueries({ queryKey: ['technician', technicianId] });
    },
  });
}

export function useAddServiceArea() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async ({
      technicianId,
      serviceAreaId,
    }: {
      technicianId: string;
      serviceAreaId: string;
    }) => {
      const { data } = await apiClient.post(endpoints.admin.technicianAreas(technicianId), {
        serviceAreaId,
      });
      return data;
    },
    onSuccess: (_, { technicianId }) => {
      qc.invalidateQueries({ queryKey: ['technician', technicianId] });
    },
  });
}

export function useRemoveServiceArea() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async ({
      technicianId,
      serviceAreaId,
    }: {
      technicianId: string;
      serviceAreaId: string;
    }) => {
      const { data } = await apiClient.delete(
        endpoints.admin.technicianArea(technicianId, serviceAreaId),
      );
      return data;
    },
    onSuccess: (_, { technicianId }) => {
      qc.invalidateQueries({ queryKey: ['technician', technicianId] });
    },
  });
}
