import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/fcm_service.dart';
import '../../../core/storage/local_storage.dart';
import '../data/auth_repository.dart';
import '../domain/auth_state.dart';
import '../../onboarding/presentation/onboarding_provider.dart';
import '../../profile/presentation/profile_provider.dart';
import '../../notifications/presentation/notification_provider.dart';
import '../../jobs/presentation/job_provider.dart';
import '../../jobs/presentation/offer_provider.dart';
import '../../earnings/presentation/earnings_provider.dart';

final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthInitial();

  AuthRepository get _repo => ref.read(authRepositoryProvider);
  LocalStorage get _storage => ref.read(localStorageProvider);

  /// Check for existing session on app startup.
  /// Tries cached user first for instant UI, then refreshes from server.
  Future<void> checkAuthStatus() async {
    state = const AuthLoading();
    try {
      // 1. Try cached user for instant feedback
      final cachedUser = await _repo.getCachedUser();
      if (cachedUser != null) {
        state = AuthAuthenticated(cachedUser);
        // Sync FCM token for cached session
        ref.read(fcmServiceProvider).initialize().catchError((e) {
          debugPrint('[AuthNotifier] FCM cached session sync error: $e');
        });
        // 2. Background refresh from server (non-blocking)
        _refreshProfileInBackground();
        return;
      }

      // 3. No cached user — check if tokens exist
      final isLoggedIn = await _storage.isLoggedIn();
      if (!isLoggedIn) {
        state = const AuthUnauthenticated();
        return;
      }

      // 4. Tokens exist but no cache — try to fetch from server
      final user = await _repo.getCurrentUser();
      state = AuthAuthenticated(user);
      // Sync FCM token
      ref.read(fcmServiceProvider).initialize().catchError((e) {
        debugPrint('[AuthNotifier] FCM init error: $e');
      });
    } catch (e) {
      debugPrint('[AuthNotifier] checkAuthStatus failed: $e');
      state = const AuthUnauthenticated();
    }
  }

  /// Send OTP to the given phone number.
  /// Returns the raw response map (contains cooldownSeconds, devOtp, etc.)
  Future<Map<String, dynamic>> sendOtp(String phone) async {
    try {
      final result = await _repo.sendOtp(phone);
      // Don't transition state — let the screen handle navigation
      return result;
    } catch (e) {
      rethrow;
    }
  }

  /// Verify OTP and authenticate the user.
  /// On success, transitions to AuthAuthenticated.
  Future<void> verifyOtp(String phone, String otp) async {
    try {
      // 1. Wipe previous session data and state completely
      await _storage.clearAll();
      _resetUserSession();

      final result = await _repo.verifyOtp(phone, otp);

      final accessToken = result['accessToken'] as String?;
      final refreshToken = result['refreshToken'] as String?;
      final userData = result['user'] as Map<String, dynamic>?;

      if (accessToken == null || refreshToken == null || userData == null) {
        throw Exception('Invalid response from server');
      }

      // Save tokens
      await _storage.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );

      // Save user data for cache
      await _storage.saveUserData(userData);

      final user = AuthUser.fromJson(userData);
      state = AuthAuthenticated(user);
      ref.invalidate(profileProvider);
      // Sync FCM token on successful login
      ref.read(fcmServiceProvider).initialize().catchError((e) {
        debugPrint('[AuthNotifier] FCM login sync error: $e');
      });
    } catch (e) {
      state = AuthError(_humanizeError(e), phone: phone);
      rethrow;
    }
  }

  /// Logout: clear tokens and update state.
  Future<void> logout() async {
    try {
      await _repo.logout();
    } catch (e) {
      debugPrint('[AuthNotifier] Logout API call failed: $e');
    }
    await _storage.clearAll();
    _resetUserSession();
    state = const AuthUnauthenticated();
  }

  /// Called by AuthInterceptor when tokens are irrecoverably expired.
  /// Does NOT call the logout API (token is already invalid).
  void forceLogout() {
    _storage.clearAll();
    _resetUserSession();
    state = const AuthUnauthenticated();
  }

  /// Reset all user-scoped providers to prevent data leak across accounts
  void _resetUserSession() {
    ref.invalidate(setupWizardProvider);
    ref.invalidate(profileProvider);
    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadCountProvider);
    ref.invalidate(activeJobProvider);
    ref.invalidate(currentJobProvider);
    ref.invalidate(upcomingJobsProvider);
    ref.invalidate(jobHistoryProvider);
    ref.invalidate(offersProvider);
    ref.invalidate(offerCountProvider);
    ref.invalidate(earningsProvider);
  }

  /// Refresh the user profile from the server.
  Future<void> refreshProfile() async {
    if (state is! AuthAuthenticated) return;
    try {
      final user = await _repo.getCurrentUser();
      await _storage.saveUserData(user.toJson());
      state = AuthAuthenticated(user);
    } catch (e) {
      debugPrint('[AuthNotifier] refreshProfile failed: $e');
    }
  }

  /// Update local user fields after a profile edit without waiting for network.
  void updateUser({String? name, String? email, String? profilePictureUrl}) {
    if (state is AuthAuthenticated) {
      final current = (state as AuthAuthenticated).user;
      final updated = current.copyWith(
        name: name ?? current.name,
        email: email ?? current.email,
        profilePictureUrl: profilePictureUrl ?? current.profilePictureUrl,
      );
      _storage.saveUserData(updated.toJson());
      state = AuthAuthenticated(updated);
    }
  }

  /// Clear any error state, returning to unauthenticated.
  void clearError() {
    if (state is AuthError) {
      state = const AuthUnauthenticated();
    }
  }

  /// Non-blocking profile refresh for use after cached user load.
  void _refreshProfileInBackground() {
    Future.microtask(() async {
      try {
        final user = await _repo.getCurrentUser();
        await _storage.saveUserData(user.toJson());
        if (state is AuthAuthenticated) {
          state = AuthAuthenticated(user);
        }
      } catch (e) {
        debugPrint('[AuthNotifier] Background profile refresh failed: $e');
        // Don't change state — cached user is still valid
      }
    });
  }

  String _humanizeError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('invalid') || msg.contains('incorrect')) {
      return 'Incorrect OTP. Please try again.';
    }
    if (msg.contains('expired')) {
      return 'OTP has expired. Please request a new one.';
    }
    if (msg.contains('attempt')) {
      return 'Too many attempts. Please request a new OTP.';
    }
    if (msg.contains('network') || msg.contains('internet')) {
      return 'No internet connection.';
    }
    return 'Verification failed. Please try again.';
  }
}
