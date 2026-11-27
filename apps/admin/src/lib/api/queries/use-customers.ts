import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';

import type { Customer, CustomerQueryParams, PaginatedResponse } from '@/lib/types';

import { apiClient } from '../client';
import { endpoints } from '../endpoints';

export function useCustomers(params?: CustomerQueryParams) {
  return useQuery({
    queryKey: ['customers', params],
    queryFn: async () => {
      const { data } = await apiClient.get<PaginatedResponse<Customer>>(endpoints.admin.customers, {
        params,
      });
      return data.data;
    },
  });
}

export function useCustomer(id: string) {
  return useQuery({
    queryKey: ['customer', id],
    queryFn: async () => {
      const { data } = await apiClient.get<{ data: Customer }>(endpoints.admin.customer(id));
      return data.data;
    },
    enabled: !!id,
  });
}

export function useUpdateCustomerStatus() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async ({ userId, isActive }: { userId: string; isActive: boolean }) => {
      const { data } = await apiClient.patch(endpoints.admin.customerStatus(userId), { isActive });
      return data;
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['customers'] });
    },
  });
}

export function useCreateCustomer() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (payload: { name: string; phone?: string; email?: string }) => {
      const { data } = await apiClient.post(endpoints.admin.customers, payload);
      return data;
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['customers'] });
    },
  });
}

export function useUpdateCustomerDetails() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async ({
      id,
      payload,
    }: {
      id: string;
      payload: { name?: string; email?: string };
    }) => {
      const { data } = await apiClient.patch(endpoints.admin.customerDetails(id), payload);
      return data;
    },
    onSuccess: (_, { id }) => {
      qc.invalidateQueries({ queryKey: ['customers'] });
      qc.invalidateQueries({ queryKey: ['customer', id] });
    },
  });
}

export function useNotifyCustomerProfile() {
  return useMutation({
    mutationFn: async ({ id, message }: { id: string; message: string }) => {
      const { data } = await apiClient.post(endpoints.admin.customerNotifyProfile(id), { message });
      return data;
    },
  });
}
