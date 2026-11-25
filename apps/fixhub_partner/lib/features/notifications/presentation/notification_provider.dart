import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/notification_repository.dart';

final notificationsProvider =
    AsyncNotifierProvider<NotificationsNotifier, List<AppNotification>>(NotificationsNotifier.new);

class NotificationsNotifier extends AsyncNotifier<List<AppNotification>> {
  late NotificationRepository _repository;
  Timer? _syncTimer;

  @override
  FutureOr<List<AppNotification>> build() async {
    _repository = ref.watch(notificationRepositoryProvider);
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      load(silent: true);
    });
    ref.onDispose(() {
      _syncTimer?.cancel();
    });
    try {
      return await _repository.listNotifications();
    } catch (e) {
      debugPrint('[NotificationsNotifier] build error: $e');
      if (state.hasValue && state.value != null) {
        return state.value!;
      }
      rethrow;
    }
  }

  /// Reload notifications.
  /// If [silent] is true, avoids replacing active state with loading spinner.
  Future<void> load({bool silent = false}) async {
    if (!silent && !state.hasValue) {
      state = const AsyncValue.loading();
    }
    try {
      final items = await _repository.listNotifications();
      state = AsyncValue.data(items);
    } catch (e, st) {
      debugPrint('[NotificationsNotifier] load error: $e');
      // Only transition to error if we don't already have data to display
      if (!state.hasValue) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      await _repository.markAsRead(id);
    } catch (e) {
      debugPrint('[NotificationsNotifier] markAsRead error: $e');
    }
    state = state.whenData((list) => list.map((n) {
          if (n.id == id) {
            return AppNotification(
              id: n.id,
              title: n.title,
              body: n.body,
              type: n.type,
              isRead: true,
              createdAt: n.createdAt,
              data: n.data,
            );
          }
          return n;
        }).toList());
  }

  Future<void> markAllAsRead() async {
    try {
      await _repository.markAllAsRead();
    } catch (e) {
      debugPrint('[NotificationsNotifier] markAllAsRead error: $e');
    }
    state = state.whenData((list) => list
        .map((n) => AppNotification(
              id: n.id,
              title: n.title,
              body: n.body,
              type: n.type,
              isRead: true,
              createdAt: n.createdAt,
              data: n.data,
            ))
        .toList());
  }
}

final unreadCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationsProvider);
  final list = notifications.value ?? notifications.asData?.value ?? const [];
  return list.where((n) => !n.isRead).length;
});
