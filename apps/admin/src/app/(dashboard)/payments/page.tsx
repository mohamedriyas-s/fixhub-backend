'use client';

import { useMutation, useQueryClient } from '@tanstack/react-query';
import type { ColumnDef } from '@tanstack/react-table';
import * as React from 'react';
import { toast } from 'sonner';

import { DataTable, SortableHeader } from '@/components/data-table/data-table';
import { Badge, Button, Tabs } from '@/components/ui';
import { apiClient } from '@/lib/api/client';
import { endpoints } from '@/lib/api/endpoints';
import { usePayments } from '@/lib/api/queries/use-payments';
import { formatCurrency, formatDateTime, paymentStatusVariant } from '@/lib/utils';

export default function PaymentsPage() {
  const [tab, setTab] = React.useState('all');
  const [page, setPage] = React.useState(1);
  const queryClient = useQueryClient();

  // Payments are fetched directly from the dedicated payments endpoint
  const { data, isLoading } = usePayments({ page, limit: 20 });

  const refundMutation = useMutation({
    mutationFn: async (paymentId: string) => {
      const { data } = await apiClient.post(endpoints.payments.refund(paymentId));
      return data;
    },
    onSuccess: () => {
      toast.success('Payment refunded successfully');
      queryClient.invalidateQueries({ queryKey: ['bookings'] });
    },
    onError: (error: any) => {
      toast.error(error?.response?.data?.message || 'Failed to refund payment');
    },
  });

  const columns: ColumnDef<any, unknown>[] = [
    {
      id: 'bookingNumber',
      header: 'Booking',
      cell: ({ row }) => (
        <span className="font-mono text-xs font-semibold text-[#1F2937]">
          {row.original.booking?.bookingNumber ?? '—'}
        </span>
      ),
      size: 160,
    },
    {
      id: 'customer',
      header: 'Customer',
      cell: ({ row }) => (
        <div>
          <p className="text-sm font-medium text-[#111827]">
            {row.original.booking?.customer?.user?.name ?? '—'}
          </p>
          <p className="text-xs text-[#9CA3AF]">
            {row.original.booking?.customer?.user?.phone ||
              row.original.booking?.customer?.user?.email ||
              '—'}
          </p>
        </div>
      ),
      size: 180,
    },
    {
      id: 'amount',
      header: ({ column }) => <SortableHeader column={column}>Amount</SortableHeader>,
      accessorFn: (row) => row.amount,
      cell: ({ row }) => (
        <span className="text-sm font-semibold text-[#111827]">
          {row.original.amount ? formatCurrency(row.original.amount) : '—'}
        </span>
      ),
      size: 120,
    },
    {
      id: 'method',
      header: 'Method',
      cell: ({ row }) => (
        <span className="text-sm text-[#374151]">{row.original.method ?? '—'}</span>
      ),
      size: 110,
    },
    {
      id: 'status',
      header: 'Status',
      cell: ({ row }) => {
        const ps = row.original.status;
        return ps ? (
          <Badge variant={paymentStatusVariant(ps as any)}>{ps}</Badge>
        ) : (
          <span className="text-xs text-[#9CA3AF]">No payment</span>
        );
      },
      size: 130,
    },
    {
      id: 'gatewayId',
      header: 'Gateway ID',
      cell: ({ row }) => (
        <span className="font-mono text-xs text-[#6B7280]">
          {row.original.razorpayPaymentId ?? '—'}
        </span>
      ),
      size: 200,
    },
    {
      id: 'date',
      header: 'Date',
      cell: ({ row }) => (
        <span className="text-xs text-[#9CA3AF]">
          {row.original.paidAt
            ? formatDateTime(row.original.paidAt)
            : formatDateTime(row.original.createdAt)}
        </span>
      ),
      size: 150,
    },
    {
      id: 'actions',
      header: '',
      cell: ({ row }) => {
        const payment = row.original;
        if (!payment || payment.status !== 'CAPTURED') return null;

        return (
          <Button
            variant="outline"
            size="sm"
            onClick={() => handleRefund(payment.id)}
            disabled={true}
          >
            {refundMutation.isPending && refundMutation.variables === payment.id
              ? 'Refunding...'
              : 'Refund'}
          </Button>
        );
      },
      size: 100,
    },
  ];

  const pageCount = data?.meta ? Math.ceil(data.meta.total / 20) : 1;

  const handleRefund = (paymentId: string) => {
    if (
      window.confirm('Are you sure you want to refund this payment? This action cannot be undone.')
    ) {
      refundMutation.mutate(paymentId);
    }
  };

  return (
    <div className="space-y-4 fade-in">
      <div>
        <h1 className="text-xl font-bold text-[#111827]">Payments</h1>
        <p className="mt-0.5 text-sm text-[#6B7280]">Transaction and refund management</p>
      </div>

      <Tabs
        tabs={[
          { id: 'all', label: 'All Transactions' },
          { id: 'captured', label: 'Captured' },
          { id: 'failed', label: 'Failed' },
          { id: 'refunded', label: 'Refunded' },
        ]}
        activeTab={tab}
        onChange={setTab}
      />

      <DataTable
        columns={columns}
        data={data?.items ?? []}
        loading={isLoading}
        searchPlaceholder="Search transactions..."
        totalItems={data?.meta?.total}
        page={page}
        pageCount={pageCount}
        onPageChange={setPage}
        emptyTitle="No transactions"
        emptyDescription="Payment transactions will appear here."
      />
    </div>
  );
}
