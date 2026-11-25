import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/notifications/presentation/notification_provider.dart';
import '../../features/jobs/presentation/job_provider.dart';
import '../routing/app_router.dart';
import '../../app.dart';

final fcmServiceProvider = Provider<FcmService>((ref) {
  return FcmService(ref);
});

class FcmService {
  final Ref _ref;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  bool _isInitialized = false;

  FcmService(this._ref);

  void _invalidateNotificationAndJobProviders() {
    _ref.invalidate(unreadCountProvider);
    _ref.invalidate(notificationsProvider);
    _ref.invalidate(activeJobProvider);
    _ref.invalidate(myJobsProvider(null));
    _ref.invalidate(assignedJobsCountProvider);
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // Request permission
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      debugPrint('FCM: Permission granted');

      // Get token and sync to backend
      try {
        final token = await _messaging.getToken();
        if (token != null) {
          debugPrint('FCM: Token obtained, syncing...');
          await syncToken(token);
        }
      } catch (e) {
        debugPrint('FCM: Failed to get token: $e');
      }

      // Listen for token refresh
      _messaging.onTokenRefresh.listen(syncToken);

      // Foreground messages — show a SnackBar and invalidate caches
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('FCM: Foreground message: ${message.messageId}');
        _invalidateNotificationAndJobProviders();

        final notification = message.notification;
        final bookingId = message.data['bookingId']?.toString();
        _showForegroundBanner(
          title: notification?.title ?? message.data['title']?.toString() ?? 'FixHub',
          body: notification?.body ?? message.data['body']?.toString() ?? '',
          bookingId: bookingId,
        );
      });

      void handleMessageNavigation(RemoteMessage message) {
        _invalidateNotificationAndJobProviders();
        final bookingId = message.data['bookingId']?.toString();
        if (bookingId != null && bookingId.isNotEmpty) {
          _ref.read(routerProvider).push('/job-details/$bookingId');
        } else {
          _ref.read(routerProvider).push('/notifications');
        }
      }

      // When app opened from a background notification tap
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('FCM: Opened from notification: ${message.messageId}');
        handleMessageNavigation(message);
      });

      // Check if app was launched from a terminated-state notification
      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('FCM: App launched from notification: ${initialMessage.messageId}');
        await Future.delayed(const Duration(milliseconds: 500));
        handleMessageNavigation(initialMessage);
      }
    } else {
      debugPrint('FCM: Permission not granted (${settings.authorizationStatus})');
    }
  }

  /// Show a floating SnackBar for foreground push notifications.
  void _showForegroundBanner({
    required String title,
    required String body,
    String? bookingId,
  }) {
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: Colors.white,
              ),
            ),
            if (body.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  body,
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
        backgroundColor: const Color(0xFF1F1F1F),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: () {
            if (bookingId != null && bookingId.isNotEmpty) {
              _ref.read(routerProvider).push('/job-details/$bookingId');
            } else {
              _ref.read(routerProvider).push('/notifications');
            }
          },
        ),
      ),
    );
  }

  /// Sync FCM token via the auth device registration endpoint.
  Future<void> syncToken(String token) async {
    try {
      final platform = Platform.isIOS ? 'IOS' : 'ANDROID';
      await _ref.read(authRepositoryProvider).registerDevice(token, platform);
      debugPrint('FCM: Token synced successfully');
    } catch (e) {
      debugPrint('FCM: Failed to sync token: $e');
    }
  }
}
