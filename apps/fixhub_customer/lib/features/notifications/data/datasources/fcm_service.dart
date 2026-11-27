import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/providers/notification_provider.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../firebase_options.dart';

// ─── Background handler (top-level, required by FCM) ─────────────────────────

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('[FCM] Background message: ${message.messageId}');
  // Do NOT call showLocalNotification here when the backend sends a
  // `notification` block — Android/iOS already renders the system tray
  // notification automatically in background/terminated states.
}

// ─── Local notifications plugin (singleton) ───────────────────────────────────

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

/// Android notification channel for high-importance booking alerts.
const AndroidNotificationChannel _channel = AndroidNotificationChannel(
  'fixhub_booking_alerts',
  'Booking Alerts',
  description: 'Notifications for booking status updates and job assignments.',
  importance: Importance.max,
  playSound: true,
);

// ─── Provider ─────────────────────────────────────────────────────────────────

final fcmServiceProvider = Provider<FCMService>((ref) => FCMService(ref));

// ─── Service ──────────────────────────────────────────────────────────────────

/// Handles FCM token lifecycle and local notification display.
///
/// Initialisation must only be called AFTER the user has a valid access token
/// (i.e. after successful OTP verification or restored session on splash).
///
/// Call order:
///   1. [initLocalNotifications] — once at app start (no network needed).
///   2. [registerAfterLogin]    — after auth succeeds (needs network + token).
class FCMService {
  FCMService(this._ref);

  final Ref _ref;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // ── 1. Local notification setup (no network, call at app start) ─────────────

  static Future<void> initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: darwinInit),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create the Android channel so foreground messages can be shown.
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_channel);
  }

  /// Shows a local notification for a [RemoteMessage].
  /// Called both for foreground (onMessage) and background (background handler).
  static Future<void> showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: message.data['bookingId'] as String?,
    );
  }

  /// Deep-link handler when the user taps a local notification.
  static void _onNotificationTap(NotificationResponse response) {
    final bookingId = response.payload;
    if (bookingId != null && bookingId.isNotEmpty) {
      // Navigate using the global navigator key set in app_router.dart.
      // We import it lazily to avoid circular deps.
      _navigateToBooking(bookingId);
    }
  }

  static void _navigateToBooking(String bookingId) {
    // app_router.dart exposes navigatorKey — we call GoRouter via context.
    // Since this may be invoked without a BuildContext (e.g. from background),
    // we push through the global navigator key.
    try {
      // GoRouter.of cannot be called here; use a global key registered in app_router.
      // The key is imported dynamically below — this avoids a circular import.
      // ignore: avoid_dynamic_calls
      _pendingBookingRoute = bookingId;
    } catch (_) {}
  }

  /// If a notification was tapped while the app was terminated, this holds
  /// the bookingId to navigate to once the app is ready.
  static String? _pendingBookingRoute;

  /// Call this from the home screen / shell scaffold initState to consume
  /// any pending notification deep-link.
  static String? consumePendingRoute() {
    final route = _pendingBookingRoute;
    _pendingBookingRoute = null;
    return route;
  }

  // ── 2. Token registration (call after auth succeeds) ─────────────────────────

  /// Sets up foreground/open listeners once and always syncs the FCM token
  /// with the backend after login or session restore.
  bool _listenersInitialized = false;

  Future<void> registerAfterLogin() async {
    // Wire foreground & tap listeners (idempotent).
    if (!_listenersInitialized) {
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpen);
      _messaging.onTokenRefresh.listen((newToken) async {
        debugPrint('[FCM] Token refreshed.');
        await _sendTokenToBackend(newToken);
      });
      _listenersInitialized = true;
    }

    // Request permissions (iOS / Android 13+).
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('[FCM] Permission denied by user.');
      return;
    }

    debugPrint('[FCM] Permission: ${settings.authorizationStatus}');

    // Fetch token with retry — Firebase Installations service can be flaky.
    final token = await _fetchTokenWithRetry();
    if (token != null) {
      await _sendTokenToBackend(token);
    }

    // Check if the app was launched from a terminated state via a notification.
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationOpen(initialMessage);
    }
  }

  // ── Foreground message handler ────────────────────────────────────────────────

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('[FCM] Foreground message: ${message.notification?.title}');
    _ref.invalidate(notificationsProvider);
    await showLocalNotification(message);
  }

  /// Called when the user taps a notification while the app is in the background
  /// (but not terminated).
  void _handleNotificationOpen(RemoteMessage message) {
    final bookingId = message.data['bookingId'] as String?;
    if (bookingId != null && bookingId.isNotEmpty) {
      _pendingBookingRoute = bookingId;
      debugPrint('[FCM] Notification opened → bookingId: $bookingId');
    }
  }

  // ── Token helpers ─────────────────────────────────────────────────────────────

  /// Tries to get an FCM token up to [maxAttempts] times with exponential back-off.
  /// Returns null if all attempts fail — the app continues normally.
  Future<String?> _fetchTokenWithRetry({int maxAttempts = 4}) async {
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final token = await _messaging
            .getToken()
            .timeout(const Duration(seconds: 10));
        if (token != null) {
          debugPrint('[FCM] Token obtained on attempt $attempt.');
          return token;
        }
      } catch (e) {
        final delay = Duration(seconds: attempt * 2); // 2s, 4s, 6s, 8s
        debugPrint('[FCM] getToken attempt $attempt failed: $e. '
            'Retrying in ${delay.inSeconds}s...');
        if (attempt < maxAttempts) {
          await Future.delayed(delay);
        }
      }
    }
    debugPrint('[FCM] All token fetch attempts failed. Push disabled for this session.');
    return null;
  }

  Future<void> _sendTokenToBackend(String token) async {
    try {
      final dio = _ref.read(dioProvider);
      await dio.post(ApiEndpoints.registerDevice, data: {
        'deviceToken': token,
        'platform': _deviceType(),
      });
      debugPrint('[FCM] Token registered with backend.');
    } catch (e) {
      // Non-fatal — the token will be re-sent on next app start.
      debugPrint('[FCM] Failed to register token with backend: $e');
    }
  }

  String _deviceType() {
    if (kIsWeb) return 'WEB';
    if (Platform.isAndroid) return 'ANDROID';
    if (Platform.isIOS) return 'IOS';
    return 'UNKNOWN';
  }
}
