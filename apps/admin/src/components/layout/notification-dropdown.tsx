'use client';

import { formatDistanceToNow } from 'date-fns';
import {
  AlertCircle,
  Bell,
  Check,
  CheckCircle2,
  Clock,
  MapPin,
  RefreshCw,
  Wrench,
  X,
  XCircle,
} from 'lucide-react';
import { useRouter } from 'next/navigation';
import { useEffect, useRef, useState } from 'react';

import { AdminNotification, useAdminNotifications } from '@/lib/hooks/use-admin-notifications';
import { cn } from '@/lib/utils';

export function NotificationDropdown() {
  const [isOpen, setIsOpen] = useState(false);
  const dropdownRef = useRef<HTMLDivElement>(null);
  const router = useRouter();
  const {
    notifications,
    unreadCount,
    markAsRead,
    markAllAsRead,
    deleteNotification,
    deleteAllNotifications,
  } = useAdminNotifications();

  useEffect(() => {
    function handleClickOutside(event: MouseEvent) {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
        setIsOpen(false);
      }
    }
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  const handleNotificationClick = (notification: AdminNotification) => {
    if (!notification.isRead) {
      markAsRead(notification.id);
    }

    // Navigate based on type
    if (notification.metadata?.bookingId) {
      router.push(`/bookings/${notification.metadata.bookingId}`);
    } else if (notification.metadata?.technicianId) {
      router.push(`/technicians/${notification.metadata.technicianId}`);
    }
    setIsOpen(false);
  };

  const getIcon = (type: string) => {
    switch (type) {
      case 'NEW_BOOKING':
        return <CheckCircle2 className="h-5 w-5 text-green-500" />;
      case 'BOOKING_CANCELLED':
        return <XCircle className="h-5 w-5 text-red-500" />;
      case 'TECHNICIAN_ASSIGNED':
        return <Wrench className="h-5 w-5 text-blue-500" />;
      case 'JOB_DECLINED':
        return <AlertCircle className="h-5 w-5 text-orange-500" />;
      case 'VERIFICATION_SUBMITTED':
        return <Clock className="h-5 w-5 text-purple-500" />;
      case 'TECHNICIAN_VERIFIED':
        return <CheckCircle2 className="h-5 w-5 text-green-500" />;
      case 'TECHNICIAN_REJECTED':
        return <XCircle className="h-5 w-5 text-red-500" />;
      case 'PAYMENT_CAPTURED':
        return <Check className="h-5 w-5 text-emerald-500" />;
      case 'REFUND_PROCESSED':
        return <RefreshCw className="h-5 w-5 text-blue-500" />;
      case 'SERVICE_AREA_REQUEST':
        return <MapPin className="h-5 w-5 text-pink-500" />;
      default:
        return <Bell className="h-5 w-5 text-gray-500" />;
    }
  };

  return (
    <div className="relative" ref={dropdownRef}>
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="relative flex h-8 w-8 items-center justify-center rounded-lg text-[#6B7280] hover:bg-[#F3F4F6] transition-colors"
      >
        <Bell className="h-4 w-4" />
        {unreadCount > 0 && (
          <span className="absolute top-1 right-1 flex h-2 w-2">
            <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-red-400 opacity-75"></span>
            <span className="relative inline-flex rounded-full h-2 w-2 bg-red-500"></span>
          </span>
        )}
      </button>

      {isOpen && (
        <div className="absolute right-0 mt-2 w-80 sm:w-96 rounded-xl bg-white shadow-lg ring-1 ring-black ring-opacity-5 z-50 overflow-hidden flex flex-col max-h-[85vh]">
          <div className="flex items-center justify-between border-b border-gray-100 px-4 py-3 bg-gray-50/50">
            <div className="flex items-center gap-2">
              <h3 className="font-semibold text-gray-900">Notifications</h3>
              {unreadCount > 0 && (
                <span className="bg-blue-100 text-blue-700 text-xs font-medium px-2 py-0.5 rounded-full">
                  {unreadCount} new
                </span>
              )}
            </div>
            <div className="flex items-center gap-3">
              {unreadCount > 0 && (
                <button
                  onClick={(e) => {
                    e.stopPropagation();
                    markAllAsRead();
                  }}
                  className="text-xs font-medium text-blue-600 hover:text-blue-700"
                >
                  Mark all as read
                </button>
              )}
              {notifications.length > 0 && (
                <button
                  onClick={(e) => {
                    e.stopPropagation();
                    deleteAllNotifications();
                  }}
                  className="text-xs font-medium text-red-600 hover:text-red-700"
                >
                  Delete all
                </button>
              )}
            </div>
          </div>

          <div className="flex-1 overflow-y-auto">
            {notifications.length === 0 ? (
              <div className="flex flex-col items-center justify-center py-12 text-center px-4">
                <div className="h-12 w-12 rounded-full bg-gray-50 flex items-center justify-center mb-3">
                  <Bell className="h-6 w-6 text-gray-400" />
                </div>
                <p className="text-sm font-medium text-gray-900">All caught up!</p>
                <p className="text-xs text-gray-500 mt-1">
                  Check back later for new notifications.
                </p>
              </div>
            ) : (
              <ul className="divide-y divide-gray-50">
                {notifications.map((notification) => (
                  <li
                    key={notification.id}
                    onClick={() => handleNotificationClick(notification)}
                    className={cn(
                      'p-4 hover:bg-gray-50 cursor-pointer transition-colors flex gap-3',
                      !notification.isRead && 'bg-blue-50/30',
                    )}
                  >
                    <div className="flex-shrink-0 mt-0.5">{getIcon(notification.type)}</div>
                    <div className="flex-1 min-w-0">
                      <p
                        className={cn(
                          'text-sm font-medium',
                          !notification.isRead ? 'text-gray-900' : 'text-gray-700',
                        )}
                      >
                        {notification.title}
                      </p>
                      <p className="text-sm text-gray-500 mt-0.5 line-clamp-2">
                        {notification.body}
                      </p>
                      <p className="text-xs text-gray-400 mt-1.5 font-medium">
                        {formatDistanceToNow(new Date(notification.createdAt), { addSuffix: true })}
                      </p>
                    </div>
                    <div className="flex-shrink-0 flex items-start gap-1.5">
                      {!notification.isRead && (
                        <div className="h-2 w-2 rounded-full bg-blue-600 mt-1.5" />
                      )}
                      <button
                        type="button"
                        aria-label="Delete notification"
                        onClick={(e) => {
                          e.stopPropagation();
                          deleteNotification(notification.id);
                        }}
                        className="p-0.5 rounded text-gray-400 hover:text-red-600 hover:bg-red-50 transition-colors"
                      >
                        <X className="h-3.5 w-3.5" />
                      </button>
                    </div>
                  </li>
                ))}
              </ul>
            )}
          </div>

          <div className="border-t border-gray-100 p-2 bg-gray-50/50">
            <button
              onClick={() => {
                setIsOpen(false);
                router.push('/notifications');
              }}
              className="w-full text-center text-sm font-medium text-gray-600 hover:text-gray-900 py-2 rounded-lg hover:bg-gray-100 transition-colors"
            >
              View all notifications
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
