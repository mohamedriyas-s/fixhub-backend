import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/local_storage.dart';
import '../domain/auth_state.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.read(dioProvider), ref.read(localStorageProvider));
});

class AuthRepository {
  final Dio _dio;
  final LocalStorage _storage;

  AuthRepository(this._dio, this._storage);

  /// POST /auth/send-otp
  Future<Map<String, dynamic>> sendOtp(String email) async {
    final response = await _dio.post(
      ApiEndpoints.sendOtp,
      data: {'email': email},
    );
    return _unwrap(response.data);
  }

  /// POST /auth/verify-otp — returns raw response map.
  /// Token storage is now handled by the provider (single responsibility).
  Future<Map<String, dynamic>> verifyOtp(String email, String otp) async {
    final response = await _dio.post(
      ApiEndpoints.verifyOtp,
      data: {'email': email, 'otp': otp, 'role': 'TECHNICIAN'},
    );
    return _unwrap(response.data);
  }

  /// GET /auth/me — fetch current user from server
  Future<AuthUser> getCurrentUser() async {
    final response = await _dio.get(ApiEndpoints.me);
    final data = _unwrap(response.data);
    return AuthUser.fromJson(data);
  }

  /// Try to load user from local Hive cache (instant, no network).
  /// Returns null if no cached data exists.
  Future<AuthUser?> getCachedUser() async {
    try {
      final userData = await _storage.getUserData();
      if (userData == null || userData.isEmpty) return null;
      // Ensure essential fields exist
      if (userData['id'] == null) return null;
      return AuthUser.fromJson(userData);
    } catch (e) {
      debugPrint('[AuthRepository] getCachedUser failed: $e');
      return null;
    }
  }

  /// POST /auth/logout
  Future<void> logout() async {
    try {
      await _dio.post(ApiEndpoints.logout);
    } catch (_) {
      // Always clear local storage even if logout API fails
    }
    // Storage clearing is now done by the provider
  }

  /// POST /auth/device — register FCM token with correct backend DTO shape
  Future<void> registerDevice(String deviceToken, String platform) async {
    try {
      await _dio.post(
        ApiEndpoints.registerDevice,
        data: {'deviceToken': deviceToken, 'platform': platform},
      );
    } catch (_) {
      // Non-critical — don't throw
    }
  }

  Map<String, dynamic> _unwrap(dynamic data) {
    if (data is Map<String, dynamic> && data.containsKey('data')) {
      return data['data'] as Map<String, dynamic>;
    }
    return data as Map<String, dynamic>;
  }
}
