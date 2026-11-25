import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/notification_remote_datasource.dart';
import '../../data/models/notification_model.dart';
import '../../../../core/network/dio_client.dart';

final notificationRemoteDataSourceProvider = Provider<NotificationRemoteDataSource>((ref) {
  final dio = ref.watch(dioProvider);
  return NotificationRemoteDataSource(dio);
});

final notificationsProvider =
    AsyncNotifierProvider<NotificationsListNotifier, List<NotificationModel>>(
  NotificationsListNotifier.new,
);

class NotificationsListNotifier extends AsyncNotifier<List<NotificationModel>> {
  late NotificationRemoteDataSource _dataSource;
  Timer? _pollTimer;

  @override
  FutureOr<List<NotificationModel>> build() async {
    _dataSource = ref.watch(notificationRemoteDataSourceProvider);
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      refreshSilent();
    });
    ref.onDispose(() {
      _pollTimer?.cancel();
    });
    try {
      return await _dataSource.getNotifications();
    } catch (_) {
      if (state.hasValue && state.value != null) {
        return state.value!;
      }
      return const [];
    }
  }

  Future<void> refreshSilent() async {
    try {
      final items = await _dataSource.getNotifications();
      state = AsyncValue.data(items);
    } catch (_) {}
  }

  Future<void> load({bool silent = false}) async {
    if (!silent && !state.hasValue) {
      state = const AsyncValue.loading();
    }
    try {
      final items = await _dataSource.getNotifications();
      state = AsyncValue.data(items);
    } catch (e, st) {
      if (!state.hasValue) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      await _dataSource.markAsRead(id);
      state = state.whenData((list) => list.map((n) {
            if (n.id == id) {
              return n.copyWith(isRead: true);
            }
            return n;
          }).toList());
    } catch (_) {}
  }

  Future<void> markAllAsRead() async {
    try {
      await _dataSource.markAllAsRead();
      state = state.whenData((list) => list.map((n) => n.copyWith(isRead: true)).toList());
    } catch (_) {}
  }

  Future<void> deleteNotification(String id) async {
    final previous = state;
    state = state.whenData((list) => list.where((n) => n.id != id).toList());
    try {
      await _dataSource.deleteNotification(id);
    } catch (_) {
      state = previous;
    }
  }

  Future<void> deleteAll() async {
    final previous = state;
    state = const AsyncValue.data([]);
    try {
      await _dataSource.deleteAllNotifications();
    } catch (_) {
      state = previous;
    }
  }
}

class NotificationNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  Future<void> markAsRead(String id) async {
    await ref.read(notificationsProvider.notifier).markAsRead(id);
  }

  Future<void> markAllAsRead() async {
    await ref.read(notificationsProvider.notifier).markAllAsRead();
  }

  Future<void> deleteNotification(String id) async {
    await ref.read(notificationsProvider.notifier).deleteNotification(id);
  }

  Future<void> deleteAll() async {
    await ref.read(notificationsProvider.notifier).deleteAll();
  }
}

final notificationNotifierProvider = NotifierProvider<NotificationNotifier, AsyncValue<void>>(() {
  return NotificationNotifier();
});
