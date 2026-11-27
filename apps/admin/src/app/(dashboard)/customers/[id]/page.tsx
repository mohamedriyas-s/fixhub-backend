'use client';

import { ArrowLeft, MapPin } from 'lucide-react';
import Link from 'next/link';
import * as React from 'react';
import { toast } from 'sonner';

import {
  Avatar,
  Badge,
  Button,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Dialog,
  Skeleton,
} from '@/components/ui';
import {
  useCustomer,
  useNotifyCustomerProfile,
  useUpdateCustomerDetails,
  useUpdateCustomerStatus,
} from '@/lib/api/queries/use-customers';
import { formatDate } from '@/lib/utils';

function ActionDialog({
  open,
  onClose,
  title,
  actionLabel,
  isDanger,
  onConfirm,
  loading,
}: {
  open: boolean;
  onClose: () => void;
  title: string;
  actionLabel: string;
  isDanger?: boolean;
  onConfirm: (note: string) => void;
  loading?: boolean;
}) {
  const [note, setNote] = React.useState('');

  React.useEffect(() => {
    if (open) setNote('');
  }, [open]);

  const handleConfirm = () => {
    if (!note.trim()) {
      return toast.error('Please provide a reason');
    }
    onConfirm(note.trim());
  };

  return (
    <Dialog open={open} onClose={onClose} title={title}>
      <div className="space-y-4">
        <div>
          <label className="text-sm font-medium text-[#374151] mb-1 block">Reason (Required)</label>
          <textarea
            className="w-full resize-none rounded-lg border border-[#E5E7EB] bg-[#F8F8F7] px-3 py-2 text-sm text-[#374151] focus:outline-none focus:ring-2 focus:ring-[#6F7F5F33]"
            rows={3}
            placeholder="Add internal note..."
            value={note}
            onChange={(e) => setNote(e.target.value)}
          />
        </div>
        <div className="flex justify-end gap-2 pt-2">
          <Button variant="secondary" onClick={onClose}>
            Cancel
          </Button>
          <Button
            variant={isDanger ? 'danger' : 'primary'}
            onClick={handleConfirm}
            loading={loading}
            disabled={!note.trim()}
          >
            {actionLabel}
          </Button>
        </div>
      </div>
    </Dialog>
  );
}

function EditCustomerDialog({
  open,
  onClose,
  customer,
}: {
  open: boolean;
  onClose: () => void;
  customer: any;
}) {
  const [name, setName] = React.useState(customer?.user?.name ?? '');
  const [email, setEmail] = React.useState(customer?.user?.email ?? '');
  const updateMutation = useUpdateCustomerDetails();

  React.useEffect(() => {
    if (open && customer) {
      setName(customer.user?.name ?? '');
      setEmail(customer.user?.email ?? '');
    }
  }, [open, customer]);

  const handleSave = () => {
    updateMutation.mutate(
      { id: customer.id, payload: { name: name.trim(), email: email.trim() || undefined } },
      {
        onSuccess: () => {
          toast.success('Customer details updated');
          onClose();
        },
        onError: () => toast.error('Failed to update details'),
      },
    );
  };

  return (
    <Dialog open={open} onClose={onClose} title="Edit Customer">
      <div className="space-y-4">
        <div>
          <label className="text-sm font-medium text-[#374151] mb-1 block">Full Name</label>
          <input
            type="text"
            className="w-full rounded-lg border border-[#E5E7EB] bg-[#F8F8F7] px-3 py-2 text-sm text-[#374151] focus:outline-none focus:ring-2 focus:ring-[#6F7F5F33]"
            value={name}
            onChange={(e) => setName(e.target.value)}
          />
        </div>
        <div>
          <label className="text-sm font-medium text-[#374151] mb-1 block">Email</label>
          <input
            type="email"
            className="w-full rounded-lg border border-[#E5E7EB] bg-[#F8F8F7] px-3 py-2 text-sm text-[#374151] focus:outline-none focus:ring-2 focus:ring-[#6F7F5F33]"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
          />
        </div>
        <div className="flex justify-end gap-2 pt-2">
          <Button variant="secondary" onClick={onClose}>
            Cancel
          </Button>
          <Button variant="primary" onClick={handleSave} loading={updateMutation.isPending}>
            Save Changes
          </Button>
        </div>
      </div>
    </Dialog>
  );
}

export default function CustomerProfilePage({ params }: { params: Promise<{ id: string }> }) {
  const resolvedParams = React.use(params);
  const { data: customer, isLoading } = useCustomer(resolvedParams.id);
  const statusMutation = useUpdateCustomerStatus();
  const notifyMutation = useNotifyCustomerProfile();

  const [actionState, setActionState] = React.useState<{
    open: boolean;
    type: 'block' | 'activate' | null;
  }>({ open: false, type: null });
  const [editDialogOpen, setEditDialogOpen] = React.useState(false);

  if (isLoading) {
    return (
      <div className="space-y-4">
        <Skeleton className="h-8 w-48" />
        <div className="grid gap-4 lg:grid-cols-3">
          {Array.from({ length: 4 }).map((_, i) => (
            <Skeleton key={i} className="h-48 rounded-xl" />
          ))}
        </div>
      </div>
    );
  }

  if (!customer) return <div className="text-sm text-[#9CA3AF]">Customer not found.</div>;

  const name = customer.user?.name ?? 'Unknown';

  return (
    <div className="space-y-5 fade-in">
      {/* Header */}
      <div className="flex items-center gap-3">
        <Link href="/customers">
          <Button variant="ghost" size="icon" className="h-8 w-8">
            <ArrowLeft className="h-4 w-4" />
          </Button>
        </Link>
        <div className="flex flex-1 items-center gap-4">
          <Avatar name={name} size="lg" />
          <div>
            <div className="flex items-center gap-2">
              <h1 className="text-lg font-bold text-[#111827]">{name}</h1>
              <Badge variant={customer.user?.isActive ? 'success' : 'danger'}>
                {customer.user?.isActive ? 'Active' : 'Blocked'}
              </Badge>
            </div>
            <p className="text-sm text-[#6B7280]">
              {[
                customer.user?.phone || customer.user?.email,
                `Joined ${formatDate(customer.createdAt)}`,
              ]
                .filter(Boolean)
                .join(' · ')}
            </p>
          </div>
          <div className="ml-auto flex gap-2">
            <Button variant="secondary" size="sm" onClick={() => setEditDialogOpen(true)}>
              Edit Details
            </Button>
            <Button
              variant="secondary"
              size="sm"
              onClick={() =>
                setActionState({ open: true, type: customer.user?.isActive ? 'block' : 'activate' })
              }
            >
              {customer.user?.isActive ? 'Block' : 'Activate'}
            </Button>
          </div>
        </div>
      </div>

      <div className="grid gap-4 lg:grid-cols-3">
        {/* Personal Details */}
        <Card className="lg:col-span-2">
          <CardHeader>
            <CardTitle>Personal Details</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-2 gap-4">
              {[
                { label: 'Full Name', value: name },
                { label: 'Phone', value: customer.user?.phone ?? '—' },
                { label: 'Email', value: customer.user?.email ?? '—' },
                { label: 'Total Bookings', value: String(customer._count?.bookings ?? 0) },
                { label: 'Saved Addresses', value: String(customer._count?.addresses ?? 0) },
                { label: 'Joined', value: formatDate(customer.createdAt) },
              ].map(({ label, value }) => (
                <div key={label}>
                  <p className="text-[11px] text-[#9CA3AF] uppercase tracking-wide">{label}</p>
                  <p className="mt-0.5 text-sm font-medium text-[#111827]">{value}</p>
                </div>
              ))}
            </div>

            {(!customer.user?.name || !customer.user?.email) && (
              <div className="mt-6 flex items-center justify-between rounded-lg bg-[#FFFBEB] px-4 py-3 border border-[#FEF3C7]">
                <span className="text-sm text-[#92400E]">Customer profile is incomplete</span>
                <Button
                  size="sm"
                  onClick={() =>
                    notifyMutation.mutate(
                      {
                        id: customer.id,
                        message:
                          'Please complete your profile to enjoy 25% OFF on your first booking!',
                      },
                      { onSuccess: () => toast.success('Notification sent to customer') },
                    )
                  }
                  loading={notifyMutation.isPending}
                >
                  Prompt to Complete Profile
                </Button>
              </div>
            )}
          </CardContent>
        </Card>

        {/* Saved Addresses */}
        <Card>
          <CardHeader>
            <CardTitle>Saved Addresses</CardTitle>
          </CardHeader>
          <CardContent>
            {customer.addresses && customer.addresses.length > 0 ? (
              <div className="space-y-3">
                {customer.addresses.map((addr) => (
                  <div key={addr.id} className="flex gap-2 rounded-lg bg-[#F8F8F7] px-3 py-2.5">
                    <MapPin className="h-4 w-4 flex-shrink-0 text-[#9CA3AF] mt-0.5" />
                    <div>
                      <p className="text-sm font-medium text-[#374151]">{addr.label}</p>
                      <p className="text-xs text-[#6B7280]">
                        {addr.line1}, {addr.city} {addr.pincode}
                      </p>
                    </div>
                  </div>
                ))}
              </div>
            ) : (
              <p className="text-sm text-[#9CA3AF]">No addresses saved.</p>
            )}
          </CardContent>
        </Card>
      </div>

      <ActionDialog
        open={actionState.open}
        onClose={() => setActionState({ open: false, type: null })}
        title={actionState.type === 'block' ? 'Block Customer' : 'Activate Customer'}
        actionLabel={actionState.type === 'block' ? 'Block' : 'Activate'}
        isDanger={actionState.type === 'block'}
        loading={statusMutation.isPending}
        onConfirm={(note) => {
          if (!customer) return;
          statusMutation.mutate(
            { userId: customer.userId, isActive: actionState.type === 'activate' },
            {
              onSuccess: () => {
                toast.success(`Account ${actionState.type}d`);
                setActionState({ open: false, type: null });
              },
            },
          );
        }}
      />

      <EditCustomerDialog
        open={editDialogOpen}
        onClose={() => setEditDialogOpen(false)}
        customer={customer}
      />
    </div>
  );
}
