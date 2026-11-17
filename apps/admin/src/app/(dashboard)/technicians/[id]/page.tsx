'use client';

import { ArrowLeft, MapPin, ShieldCheck, Star } from 'lucide-react';
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
  useTechnician,
  useUpdateTechnicianDetails,
  useUpdateTechnicianStatus,
  useVerifyTechnician,
} from '@/lib/api/queries/use-technicians';
import type { Technician, VerificationStatus } from '@/lib/types';
import { formatDate, formatDateTime, verificationStatusVariant } from '@/lib/utils';

function ActionDialog({
  open,
  onClose,
  title,
  actionLabel,
  isDanger,
  requireNote,
  onConfirm,
  loading,
}: {
  open: boolean;
  onClose: () => void;
  title: string;
  actionLabel: string;
  isDanger?: boolean;
  requireNote?: boolean;
  onConfirm: (note: string) => void;
  loading?: boolean;
}) {
  const [note, setNote] = React.useState('');

  React.useEffect(() => {
    if (open) setNote('');
  }, [open]);

  const handleConfirm = () => {
    if (requireNote && !note.trim()) {
      return toast.error('Please provide a note');
    }
    onConfirm(note.trim());
  };

  return (
    <Dialog open={open} onClose={onClose} title={title}>
      <div className="space-y-4">
        <div>
          <label className="text-sm font-medium text-[#374151] mb-1 block">
            {requireNote ? 'Note (Required)' : 'Note (Optional)'}
          </label>
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
            disabled={requireNote && !note.trim()}
          >
            {actionLabel}
          </Button>
        </div>
      </div>
    </Dialog>
  );
}

function EditTechnicianDialog({
  open,
  onClose,
  technician,
}: {
  open: boolean;
  onClose: () => void;
  technician: Technician | null;
}) {
  const [name, setName] = React.useState(technician?.user?.name ?? '');
  const [email, setEmail] = React.useState(technician?.user?.email ?? '');
  const updateMutation = useUpdateTechnicianDetails();

  React.useEffect(() => {
    if (open && technician) {
      setName(technician.user?.name ?? '');
      setEmail(technician.user?.email ?? '');
    }
  }, [open, technician]);

  const handleSave = () => {
    updateMutation.mutate(
      { id: technician.id, payload: { name: name.trim(), email: email.trim() || undefined } },
      {
        onSuccess: () => {
          toast.success('Technician details updated');
          onClose();
        },
        onError: () => toast.error('Failed to update details'),
      },
    );
  };

  return (
    <Dialog open={open} onClose={onClose} title="Edit Technician">
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

export default function TechnicianProfilePage({ params }: { params: Promise<{ id: string }> }) {
  const resolvedParams = React.use(params);
  const { data: tech, isLoading } = useTechnician(resolvedParams.id);
  const verifyMutation = useVerifyTechnician();
  const statusMutation = useUpdateTechnicianStatus();

  const [actionState, setActionState] = React.useState<{
    open: boolean;
    type: 'verify' | 'reject' | 'suspend' | 'activate' | null;
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

  if (!tech) return <div className="text-sm text-[#9CA3AF]">Technician not found.</div>;

  const hasName = Boolean(tech.user?.name && tech.user.name.trim());
  const name = hasName ? tech.user!.name! : 'Incomplete Registration';
  const vs = tech.verificationStatus as VerificationStatus;

  return (
    <div className="space-y-5 fade-in">
      {/* Header */}
      <div className="flex items-center gap-3">
        <Link href="/technicians">
          <Button variant="ghost" size="icon" className="h-8 w-8">
            <ArrowLeft className="h-4 w-4" />
          </Button>
        </Link>
        <div className="flex flex-1 items-center gap-4">
          <Avatar name={hasName ? name : 'Incomplete'} src={tech.profilePictureUrl} size="lg" />
          <div>
            <div className="flex items-center gap-2">
              <h1 className="text-lg font-bold text-[#111827]">
                {hasName ? (
                  name
                ) : (
                  <span className="text-[#9CA3AF] italic">Incomplete Registration</span>
                )}
              </h1>
              {!hasName && <Badge variant="warning">Onboarding Pending</Badge>}
              <Badge variant={verificationStatusVariant(vs)}>{vs.replace('_', ' ')}</Badge>
              <Badge variant={tech.user?.isActive ? 'success' : 'danger'}>
                {tech.user?.isActive ? 'Active' : 'Suspended'}
              </Badge>
            </div>
            <p className="text-sm text-[#6B7280]">
              {tech.user?.phone} · Joined {formatDate(tech.createdAt)}
            </p>
          </div>
          <div className="ml-auto flex gap-2">
            <Button variant="secondary" size="sm" onClick={() => setEditDialogOpen(true)}>
              Edit Details
            </Button>
            {(vs === 'PENDING' || vs === 'UNDER_REVIEW') && (
              <Button
                variant="primary"
                size="sm"
                onClick={() => setActionState({ open: true, type: 'verify' })}
              >
                <ShieldCheck className="h-3.5 w-3.5" /> Verify
              </Button>
            )}
            {vs === 'PENDING' && (
              <Button
                variant="danger"
                size="sm"
                onClick={() => setActionState({ open: true, type: 'reject' })}
              >
                Reject
              </Button>
            )}
            <Button
              variant="secondary"
              size="sm"
              onClick={() =>
                setActionState({ open: true, type: tech.user?.isActive ? 'suspend' : 'activate' })
              }
            >
              {tech.user?.isActive ? 'Suspend' : 'Activate'}
            </Button>
          </div>
        </div>
      </div>

      {!hasName && (
        <div className="rounded-xl border border-[#FDE68A] bg-[#FEF3C7] p-4 text-sm text-[#92400E]">
          <p className="font-semibold">Technician Registration Incomplete</p>
          <p className="text-xs text-[#B45309] mt-0.5">
            This user verified their phone number via OTP but has not finished submitting the
            onboarding setup (name, services, and coverage areas).
          </p>
        </div>
      )}

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
                { label: 'Phone', value: tech.user?.phone ?? '—' },
                { label: 'Email', value: tech.user?.email ?? '—' },
                { label: 'Verification', value: vs.replace('_', ' ') },
                { label: 'Total Jobs', value: String(tech.totalJobs) },
                { label: 'Rating', value: `★ ${Number(tech.rating).toFixed(1)}` },
                { label: 'Availability', value: tech.isAvailable ? 'Available' : 'Offline' },
                {
                  label: 'Last Active',
                  value: tech.lastLocationAt ? formatDateTime(tech.lastLocationAt) : 'Never',
                },
                { label: 'Account Status', value: tech.user?.isActive ? 'Active' : 'Suspended' },
                { label: 'Joined', value: formatDate(tech.createdAt) },
              ].map(({ label, value }) => (
                <div key={label}>
                  <p className="text-[11px] text-[#9CA3AF] uppercase tracking-wide">{label}</p>
                  <p className="mt-0.5 text-sm font-medium text-[#111827]">{value}</p>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>

        <div className="space-y-4">
          <Card>
            <CardContent className="pt-5">
              <div className="text-center">
                <div className="text-3xl font-bold text-[#111827]">{tech.totalJobs}</div>
                <div className="mt-1 text-xs text-[#9CA3AF]">Total Jobs Completed</div>
              </div>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="pt-5">
              <div className="text-center">
                <div className="flex items-center justify-center gap-1">
                  <Star className="h-5 w-5 fill-[#F59E0B] text-[#F59E0B]" />
                  <span className="text-3xl font-bold text-[#111827]">
                    {Number(tech.rating).toFixed(1)}
                  </span>
                </div>
                <div className="mt-1 text-xs text-[#9CA3AF]">
                  Average Rating · {tech._count?.reviews ?? 0} reviews
                </div>
              </div>
            </CardContent>
          </Card>
        </div>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Documents</CardTitle>
        </CardHeader>
        <CardContent>
          {tech.documents && tech.documents.length > 0 ? (
            <div className="divide-y divide-[#F3F4F6]">
              {tech.documents.map((doc) => (
                <div key={doc.id} className="flex items-center justify-between py-3">
                  <div>
                    <p className="text-sm font-medium text-[#111827]">
                      {doc.documentType.replace('_', ' ')}
                    </p>
                    <p className="text-xs text-[#9CA3AF]">
                      Uploaded {formatDate(doc.createdAt)}
                      {doc.verifiedAt && ` · Verified ${formatDate(doc.verifiedAt)}`}
                    </p>
                  </div>
                  <div className="flex items-center gap-2">
                    <Badge variant={doc.isVerified ? 'success' : 'warning'}>
                      {doc.isVerified ? 'Verified' : 'Pending'}
                    </Badge>
                    <a href={doc.url} target="_blank" rel="noreferrer">
                      <Button variant="secondary" size="sm">
                        View
                      </Button>
                    </a>
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <p className="text-sm text-[#9CA3AF]">No documents uploaded yet.</p>
          )}
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Service Specializations</CardTitle>
        </CardHeader>
        <CardContent>
          {tech.specializations && tech.specializations.length > 0 ? (
            <div className="flex flex-wrap gap-2">
              {tech.specializations.map((spec) => (
                <div
                  key={spec.subService.id}
                  className="rounded-lg border border-[#E5E7EB] px-3 py-2"
                >
                  <p className="text-sm font-medium text-[#111827]">{spec.subService.name}</p>
                  <p className="text-xs text-[#9CA3AF]">{spec.subService.category?.name}</p>
                </div>
              ))}
            </div>
          ) : (
            <p className="text-sm text-[#9CA3AF]">No specializations configured.</p>
          )}
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Service Areas</CardTitle>
        </CardHeader>
        <CardContent>
          {tech.serviceAreas && tech.serviceAreas.length > 0 ? (
            <div className="grid grid-cols-2 gap-3 sm:grid-cols-3">
              {tech.serviceAreas.map(({ serviceArea: area }) => (
                <div
                  key={area.id}
                  className="flex items-center gap-2 rounded-lg border border-[#E5E7EB] px-3 py-2.5"
                >
                  <MapPin className="h-4 w-4 text-[#9CA3AF]" />
                  <div>
                    <p className="text-sm font-medium text-[#111827]">{area.name}</p>
                    <p className="text-xs text-[#9CA3AF]">{area.pincode}</p>
                  </div>
                  <Badge
                    variant={area.isActive ? 'success' : 'neutral'}
                    className="ml-auto text-[10px]"
                  >
                    {area.isActive ? 'Active' : 'Off'}
                  </Badge>
                </div>
              ))}
            </div>
          ) : (
            <p className="text-sm text-[#9CA3AF]">No service areas assigned.</p>
          )}
        </CardContent>
      </Card>

      <ActionDialog
        open={actionState.open}
        onClose={() => setActionState({ open: false, type: null })}
        title={
          actionState.type === 'verify'
            ? 'Verify Technician'
            : actionState.type === 'reject'
              ? 'Reject Technician'
              : actionState.type === 'suspend'
                ? 'Suspend Account'
                : 'Activate Account'
        }
        actionLabel={
          actionState.type === 'verify'
            ? 'Verify'
            : actionState.type === 'reject'
              ? 'Reject'
              : actionState.type === 'suspend'
                ? 'Suspend'
                : 'Activate'
        }
        isDanger={actionState.type === 'reject' || actionState.type === 'suspend'}
        requireNote={actionState.type === 'reject' || actionState.type === 'suspend'}
        loading={
          actionState.type === 'verify' || actionState.type === 'reject'
            ? verifyMutation.isPending
            : statusMutation.isPending
        }
        onConfirm={(note) => {
          if (!tech) return;
          if (actionState.type === 'verify') {
            verifyMutation.mutate(
              { id: tech.id, status: 'VERIFIED' },
              {
                onSuccess: () => {
                  toast.success('Technician verified');
                  setActionState({ open: false, type: null });
                },
              },
            );
          } else if (actionState.type === 'reject') {
            verifyMutation.mutate(
              { id: tech.id, status: 'REJECTED', rejectionNote: note },
              {
                onSuccess: () => {
                  toast.error('Technician rejected');
                  setActionState({ open: false, type: null });
                },
              },
            );
          } else if (actionState.type === 'suspend' || actionState.type === 'activate') {
            statusMutation.mutate(
              { userId: tech.userId, isActive: actionState.type === 'activate' },
              {
                onSuccess: () => {
                  toast.success(`Account ${actionState.type}d`);
                  setActionState({ open: false, type: null });
                },
              },
            );
          }
        }}
      />

      <EditTechnicianDialog
        open={editDialogOpen}
        onClose={() => setEditDialogOpen(false)}
        technician={tech}
      />
    </div>
  );
}
