'use client';

import type { ColumnDef } from '@tanstack/react-table';
import { MapPin } from 'lucide-react';
import { useRouter } from 'next/navigation';
import * as React from 'react';
import { toast } from 'sonner';

import { DataTable, SortableHeader } from '@/components/data-table/data-table';
import { Avatar, Badge, Button, Dialog,Drawer, Separator  } from '@/components/ui';
import { useCreateCustomer,useCustomers, useUpdateCustomerStatus  } from '@/lib/api/queries/use-customers';
import type { Customer } from '@/lib/types';
import { formatCurrency,formatDate } from '@/lib/utils';

function CreateCustomerDialog({ open, onClose }: { open: boolean; onClose: () => void }) {
  const [name, setName] = React.useState('');
  const [phone, setPhone] = React.useState('');
  const [email, setEmail] = React.useState('');
  const createMutation = useCreateCustomer();

  React.useEffect(() => {
    if (open) {
      setName('');
      setPhone('');
      setEmail('');
    }
  }, [open]);

  const handleCreate = () => {
    if (!name.trim() || (!email.trim() && !phone.trim())) {
      return toast.error('Name and email (or phone) are required');
    }
    createMutation.mutate(
      {
        name: name.trim(),
        email: email.trim() || undefined,
        phone: phone.trim() || undefined,
      },
      {
        onSuccess: () => {
          toast.success('Customer created successfully');
          onClose();
        },
        onError: () => toast.error('Failed to create customer'),
      },
    );
  };

  return (
    <Dialog open={open} onClose={onClose} title="Add New Customer">
      <div className="space-y-4">
        <div>
          <label className="text-sm font-medium text-[#374151] mb-1 block">Full Name</label>
          <input
            type="text"
            className="w-full rounded-lg border border-[#E5E7EB] bg-[#F8F8F7] px-3 py-2 text-sm text-[#374151] focus:outline-none focus:ring-2 focus:ring-[#6F7F5F33]"
            placeholder="Jane Doe"
            value={name}
            onChange={(e) => setName(e.target.value)}
          />
        </div>
        <div>
          <label className="text-sm font-medium text-[#374151] mb-1 block">Email Address</label>
          <input
            type="email"
            className="w-full rounded-lg border border-[#E5E7EB] bg-[#F8F8F7] px-3 py-2 text-sm text-[#374151] focus:outline-none focus:ring-2 focus:ring-[#6F7F5F33]"
            placeholder="jane@example.com"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
          />
        </div>
        <div>
          <label className="text-sm font-medium text-[#374151] mb-1 block">
            Phone Number (Optional)
          </label>
          <input
            type="text"
            className="w-full rounded-lg border border-[#E5E7EB] bg-[#F8F8F7] px-3 py-2 text-sm text-[#374151] focus:outline-none focus:ring-2 focus:ring-[#6F7F5F33]"
            placeholder="+919876543210"
            value={phone}
            onChange={(e) => setPhone(e.target.value)}
          />
        </div>
        <div className="flex justify-end gap-2 pt-2">
          <Button variant="secondary" onClick={onClose}>
            Cancel
          </Button>
          <Button
            variant="primary"
            onClick={handleCreate}
            loading={createMutation.isPending}
            disabled={!name.trim() || (!email.trim() && !phone.trim())}
          >
            Create Customer
          </Button>
        </div>
      </div>
    </Dialog>
  );
}

export default function CustomersPage() {
  const router = useRouter();
  const [page, setPage] = React.useState(1);
  const [limit] = React.useState(20);
  const [createDialogOpen, setCreateDialogOpen] = React.useState(false);
  const { data, isLoading } = useCustomers({ page, limit });
  const updateStatus = useUpdateCustomerStatus();

  const columns: ColumnDef<Customer, unknown>[] = [
    {
      id: 'name',
      header: 'Customer',
      cell: ({ row }) => {
        const c = row.original;
        return (
          <div className="flex items-center gap-3">
            <Avatar name={c.user?.name} size="sm" />
            <div>
              <div className="text-sm font-medium text-[#111827]">{c.user?.name ?? '—'}</div>
              <div className="text-xs text-[#9CA3AF]">{c.user?.phone || c.user?.email || '—'}</div>
            </div>
          </div>
        );
      },
      size: 220,
    },
    {
      id: 'email',
      header: 'Email',
      cell: ({ row }) => (
        <span className="text-sm text-[#374151]">{row.original.user?.email ?? '—'}</span>
      ),
      size: 200,
    },
    {
      id: 'bookings',
      header: ({ column }) => <SortableHeader column={column}>Bookings</SortableHeader>,
      cell: ({ row }) => (
        <span className="text-sm font-medium text-[#374151]">
          {row.original._count?.bookings ?? 0}
        </span>
      ),
      size: 100,
    },
    {
      id: 'status',
      header: 'Status',
      cell: ({ row }) => (
        <Badge variant={row.original.user?.isActive ? 'success' : 'danger'}>
          {row.original.user?.isActive ? 'Active' : 'Blocked'}
        </Badge>
      ),
      size: 100,
    },
    {
      id: 'joined',
      header: 'Joined',
      accessorKey: 'createdAt',
      cell: ({ row }) => (
        <span className="text-xs text-[#9CA3AF]">{formatDate(row.original.createdAt)}</span>
      ),
      size: 110,
    },
    {
      id: 'actions',
      header: '',
      cell: ({ row }) => {
        const c = row.original;
        return (
          <div onClick={(e) => e.stopPropagation()}>
            <Button
              variant="ghost"
              size="sm"
              onClick={() =>
                updateStatus.mutate(
                  { userId: c.userId, isActive: !c.user?.isActive },
                  {
                    onSuccess: () =>
                      toast.success(c.user?.isActive ? 'Customer blocked' : 'Customer activated'),
                  },
                )
              }
            >
              {c.user?.isActive ? 'Block' : 'Activate'}
            </Button>
          </div>
        );
      },
      size: 100,
    },
  ];

  const pageCount = data?.meta ? Math.ceil(data.meta.total / limit) : 1;

  return (
    <div className="space-y-4 fade-in">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-bold text-[#111827]">Customers</h1>
          <p className="mt-0.5 text-sm text-[#6B7280]">
            {data?.meta?.total ? `${data.meta.total} registered customers` : 'Loading...'}
          </p>
        </div>
        <Button variant="primary" onClick={() => setCreateDialogOpen(true)}>
          New Customer
        </Button>
      </div>
      <DataTable
        columns={columns}
        data={data?.items ?? []}
        loading={isLoading}
        searchPlaceholder="Search customers..."
        totalItems={data?.meta?.total}
        page={page}
        pageSize={limit}
        pageCount={pageCount}
        onPageChange={setPage}
        onRowClick={(c) => router.push(`/customers/${c.id}`)}
        emptyTitle="No customers found"
      />

      <CreateCustomerDialog open={createDialogOpen} onClose={() => setCreateDialogOpen(false)} />
    </div>
  );
}
