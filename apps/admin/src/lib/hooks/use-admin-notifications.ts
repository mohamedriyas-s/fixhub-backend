import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useCallback, useEffect, useState } from 'react';
import { io, Socket } from 'socket.io-client';
import { toast } from 'sonner';

import { apiClient } from '../api/client';
import { endpoints } from '../api/endpoints';

export interface AdminNotification {
  id: string;
  type: string;
  title: string;
  body: string;
  metadata?: any;
  isRead: boolean;
  createdAt: string;
}

const WS_URL =
  process.env.NEXT_PUBLIC_WS_URL || 'https://fixhub-backend-fra0.onrender.com/admin-notifications';

export function useAdminNotifications() {
  const queryClient = useQueryClient();
  const [socket, setSocket] = useState<Socket | null>(null);
  const [isConnected, setIsConnected] = useState(false);

  // Fetch initial notifications
  const { data: notifications = [], isLoading } = useQuery<AdminNotification[]>({
    queryKey: ['adminNotifications'],
    queryFn: async () => {
      const res = await apiClient.get(endpoints.adminNotifications.list);
      return res.data.data;
    },
  });

  // Fetch unread count
  const { data: unreadCount = 0 } = useQuery<number>({
    queryKey: ['adminNotificationsUnread'],
    queryFn: async () => {
      const res = await apiClient.get(endpoints.adminNotifications.unreadCount);
      return res.data.data.count;
    },
  });

  // Connect to WebSocket
  useEffect(() => {
    // Only connect in browser and if we likely have an auth cookie (assuming apiClient works)
    if (typeof window === 'undefined') return;

    const newSocket = io(WS_URL, {
      withCredentials: true,
      transports: ['websocket', 'polling'],
      reconnectionDelay: 1000,
      reconnectionDelayMax: 5000,
      reconnectionAttempts: 10,
    });

    setSocket(newSocket);

    newSocket.on('connect', () => {
      setIsConnected(true);
      console.log('Connected to admin notifications WS');
    });

    newSocket.on('disconnect', () => {
      setIsConnected(false);
    });

    newSocket.on('notification:new', (notification: AdminNotification) => {
      // Show toast for new notification
      toast.info(notification.title, {
        description: notification.body,
        duration: 5000,
      });

      // Update query cache optimistically
      queryClient.setQueryData<AdminNotification[]>(['adminNotifications'], (old = []) => {
        return [notification, ...old];
      });
      queryClient.setQueryData<number>(['adminNotificationsUnread'], (old = 0) => old + 1);
    });

    newSocket.on('notification:read', ({ id }) => {
      queryClient.setQueryData<AdminNotification[]>(['adminNotifications'], (old = []) => {
        return old.map((n) => (n.id === id ? { ...n, isRead: true } : n));
      });
      // We'll refetch unread count to be safe
      queryClient.invalidateQueries({ queryKey: ['adminNotificationsUnread'] });
    });

    newSocket.on('notification:all_read', () => {
      queryClient.setQueryData<AdminNotification[]>(['adminNotifications'], (old = []) => {
        return old.map((n) => ({ ...n, isRead: true }));
      });
      queryClient.setQueryData<number>(['adminNotificationsUnread'], () => 0);
    });

    newSocket.on('notification:deleted', ({ id }) => {
      queryClient.setQueryData<AdminNotification[]>(['adminNotifications'], (old = []) => {
        return old.filter((n) => n.id !== id);
      });
      queryClient.invalidateQueries({ queryKey: ['adminNotificationsUnread'] });
    });

    newSocket.on('notification:all_deleted', () => {
      queryClient.setQueryData<AdminNotification[]>(['adminNotifications'], () => []);
      queryClient.setQueryData<number>(['adminNotificationsUnread'], () => 0);
    });

    return () => {
      newSocket.disconnect();
    };
  }, [queryClient]);

  // Mutations
  const markAsReadMutation = useMutation({
    mutationFn: async (id: string) => {
      await apiClient.patch(endpoints.adminNotifications.markRead(id));
      // Alternatively we could emit via socket: socket?.emit('mark_read', { id });
    },
    onSuccess: (_, id) => {
      // Optimistic update done in WS or below
      queryClient.setQueryData<AdminNotification[]>(['adminNotifications'], (old = []) => {
        return old.map((n) => (n.id === id ? { ...n, isRead: true } : n));
      });
      queryClient.invalidateQueries({ queryKey: ['adminNotificationsUnread'] });
    },
  });

  const markAllAsReadMutation = useMutation({
    mutationFn: async () => {
      await apiClient.patch(endpoints.adminNotifications.markAllRead);
    },
    onSuccess: () => {
      queryClient.setQueryData<AdminNotification[]>(['adminNotifications'], (old = []) => {
        return old.map((n) => ({ ...n, isRead: true }));
      });
      queryClient.setQueryData<number>(['adminNotificationsUnread'], () => 0);
    },
  });

  const deleteNotificationMutation = useMutation({
    mutationFn: async (id: string) => {
      await apiClient.delete(endpoints.adminNotifications.delete(id));
    },
    onSuccess: (_, id) => {
      queryClient.setQueryData<AdminNotification[]>(['adminNotifications'], (old = []) => {
        return old.filter((n) => n.id !== id);
      });
      queryClient.invalidateQueries({ queryKey: ['adminNotificationsUnread'] });
    },
  });

  const deleteAllNotificationsMutation = useMutation({
    mutationFn: async () => {
      await apiClient.delete(endpoints.adminNotifications.deleteAll);
    },
    onSuccess: () => {
      queryClient.setQueryData<AdminNotification[]>(['adminNotifications'], () => []);
      queryClient.setQueryData<number>(['adminNotificationsUnread'], () => 0);
    },
  });

  const markAsRead = useCallback(
    (id: string) => {
      markAsReadMutation.mutate(id);
    },
    [markAsReadMutation],
  );

  const markAllAsRead = useCallback(() => {
    markAllAsReadMutation.mutate();
  }, [markAllAsReadMutation]);

  const deleteNotification = useCallback(
    (id: string) => {
      deleteNotificationMutation.mutate(id);
    },
    [deleteNotificationMutation],
  );

  const deleteAllNotifications = useCallback(() => {
    deleteAllNotificationsMutation.mutate();
  }, [deleteAllNotificationsMutation]);

  return {
    notifications,
    unreadCount,
    isLoading,
    isConnected,
    markAsRead,
    markAllAsRead,
    deleteNotification,
    deleteAllNotifications,
    isMarkingRead: markAsReadMutation.isPending,
    isMarkingAllRead: markAllAsReadMutation.isPending,
    isDeleting: deleteNotificationMutation.isPending,
    isDeletingAll: deleteAllNotificationsMutation.isPending,
  };
}
