import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/error/failures.dart';
import '../../../notifications/data/datasources/fcm_service.dart';
import '../../../booking/presentation/providers/booking_flow_provider.dart';
import '../../../booking/presentation/providers/booking_provider.dart';
import '../../../notifications/presentation/providers/notification_provider.dart';
import '../../../profile/presentation/providers/address_provider.dart';

// ── Auth Status ───────────────────────────────────────────────

enum AuthStatus {
  initial,
  loading,
  otpSent,
  verifying,
  authenticated,
  unauthenticated,
  error,
}

// ── Auth State ────────────────────────────────────────────────

class AuthState {
  final AuthStatus status;
  final String? errorMessage;
  final UserModel? user;
  final String? phone;
  final String? devOtp;

  const AuthState({
    this.status = AuthStatus.initial,
    this.errorMessage,
    this.user,
    this.phone,
    this.devOtp,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? errorMessage,
    UserModel? user,
    String? phone,
    String? devOtp,
    bool clearDevOtp = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      errorMessage: errorMessage,
      user: user ?? this.user,
      phone: phone ?? this.phone,
      devOtp: clearDevOtp ? null : (devOtp ?? this.devOtp),
    );
  }

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isLoading =>
      status == AuthStatus.loading || status == AuthStatus.verifying;
}

// ── Providers ─────────────────────────────────────────────────

/// Auth repository provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dio = ref.watch(dioProvider);
  final localStorage = ref.watch(localStorageProvider);
  return AuthRepositoryImpl(AuthRemoteDataSource(dio), localStorage);
});

/// Auth state notifier provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider), ref);
});

// ── Auth Notifier ─────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  final Ref _ref;

  AuthNotifier(this._repository, this._ref) : super(const AuthState());

  /// Check if user is already logged in (on app start).
  Future<void> checkAuthStatus() async {
    try {
      final isLoggedIn = await _repository.isLoggedIn();
      if (isLoggedIn) {
        // Try to get cached user first
        final cachedUser = await _repository.getCachedUser();
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: cachedUser,
        );

        // Register FCM device token
        try {
          await _ref.read(fcmServiceProvider).registerAfterLogin();
        } catch (_) {}

        // Refresh profile in background — if token is expired/invalid, force clean logout
        try {
          final user = await _repository.getProfile();
          state = state.copyWith(user: user);
        } on Failure catch (e) {
          if (e is AuthFailure) {
            forceLogout();
          }
        } on DioException catch (e) {
          if (e.response?.statusCode == 401 || e.error is AuthFailure) {
            forceLogout();
          }
        } catch (_) {
          // Keep cached user if profile refresh fails due to network/offline
        }
      } else {
        state = state.copyWith(status: AuthStatus.unauthenticated);
      }
    } catch (_) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  /// Send OTP to phone number.
  Future<void> sendOtp(String phone) async {
    state = state.copyWith(
      status: AuthStatus.loading,
      phone: phone,
      clearDevOtp: true,
    );
    try {
      final devOtp = await _repository.sendOtp(phone);
      state = state.copyWith(status: AuthStatus.otpSent, devOtp: devOtp);
    } on Failure catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.message,
      );
    } on DioException catch (e) {
      String msg = 'Failed to send OTP. Please try again.';
      if (e.response?.data is Map && e.response?.data['message'] != null) {
        msg = e.response!.data['message'].toString();
      }
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: msg,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Failed to send OTP. Please try again.',
      );
    }
  }

  /// Verify OTP and authenticate.
  Future<void> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    state = state.copyWith(status: AuthStatus.verifying);
    try {
      _resetUserSession();
      final response = await _repository.verifyOtp(phone: phone, otp: otp);
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: response.user,
      );
      // Register FCM device token on login
      try {
        await _ref.read(fcmServiceProvider).registerAfterLogin();
      } catch (_) {}
    } on Failure catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.message,
        clearDevOtp: true,
      );
    } on DioException catch (e) {
      String msg = 'Verification failed. Please try again.';
      if (e.error is Failure) {
        msg = (e.error as Failure).message;
      } else if (e.response?.data is Map && e.response?.data['message'] != null) {
        msg = e.response!.data['message'].toString();
      }
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: msg,
        clearDevOtp: true,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Verification failed: ${e.toString().replaceFirst('Exception: ', '')}',
        clearDevOtp: true,
      );
    }
  }

  /// Resend OTP (resets to otpSent state).
  Future<void> resendOtp() async {
    final phone = state.phone;
    if (phone == null) return;
    await sendOtp(phone);
  }

  /// Fetch profile from API.
  Future<void> refreshProfile() async {
    try {
      final user = await _repository.getProfile();
      state = state.copyWith(user: user);
    } catch (_) {
      // Silently fail — keep existing user data
    }
  }

  /// Logout and clear session.
  Future<void> logout() async {
    await _repository.logout();
    _resetUserSession();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Force logout immediately without network call (token is already invalid on server).
  /// Synchronously notifies GoRouter via _RouterNotifier to redirect to Welcome/Login.
  void forceLogout() {
    _ref.read(localStorageProvider).clearAll();
    _resetUserSession();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void _resetUserSession() {
    _ref.invalidate(bookingFlowProvider);
    _ref.invalidate(bookingsProvider);
    _ref.invalidate(notificationsProvider);
    _ref.invalidate(addressesProvider);
  }

  /// Clear error state.
  void clearError() {
    state = state.copyWith(
      errorMessage: null,
    );
  }
}
