import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/domain/auth_state.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/profile_repository.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/location_tracker.dart';
import '../../../core/storage/local_storage.dart';

final profileProvider = AsyncNotifierProvider<ProfileNotifier, TechnicianProfile?>(ProfileNotifier.new);

class ProfileNotifier extends AsyncNotifier<TechnicianProfile?> {
  late ProfileRepository _repository;

  Future<void> _syncCacheWithAvailability(bool isAvailable) async {
    try {
      final storage = ref.read(localStorageProvider);
      final cached = await storage.getUserData();
      if (cached != null) {
        final updated = Map<String, dynamic>.from(cached);
        if (updated['technician'] is Map) {
          final techMap = Map<String, dynamic>.from(updated['technician'] as Map);
          techMap['isAvailable'] = isAvailable;
          updated['technician'] = techMap;
        } else {
          updated['technician'] = {'isAvailable': isAvailable};
        }
        await storage.saveUserData(updated);
      }
    } catch (_) {}
  }

  @override
  FutureOr<TechnicianProfile?> build() async {
    _repository = ref.watch(profileRepositoryProvider);
    final authState = ref.watch(authProvider);
    if (authState is! AuthAuthenticated) {
      return null;
    }
    final profile = await _repository.getProfile();
    if (profile.isAvailable) {
      ref.read(locationTrackerProvider).start();
    }
    _syncCacheWithAvailability(profile.isAvailable);
    return profile;
  }

  Future<void> load() async {
    if (ref.read(authProvider) is! AuthAuthenticated) return;
    if (state.value == null) {
      state = const AsyncValue.loading();
    }
    try {
      final profile = await _repository.getProfile();
      state = AsyncValue.data(profile);
      if (profile.isAvailable) {
        ref.read(locationTrackerProvider).start();
      } else {
        ref.read(locationTrackerProvider).stop();
      }
      _syncCacheWithAvailability(profile.isAvailable);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> toggleAvailability(bool isAvailable) async {
    final current = state.value;

    // Grab GPS position before toggling (best-effort; null is OK — backend accepts without it)
    double? lat, lng;
    final locService = ref.read(locationServiceProvider);
    try {
      final position = await locService.getCurrentPosition().timeout(
        const Duration(seconds: 3),
        onTimeout: () => null,
      );
      if (position != null) {
        lat = position.latitude;
        lng = position.longitude;
      }
    } catch (_) {}

    // Optimistic update
    if (current != null) {
      state = AsyncValue.data(TechnicianProfile(
        id: current.id,
        isAvailable: isAvailable,
        verificationStatus: current.verificationStatus,
        rating: current.rating,
        totalJobs: current.totalJobs,
        profilePictureUrl: current.profilePictureUrl,
        name: current.name,
        phone: current.phone,
        email: current.email,
        serviceAreas: current.serviceAreas,
        specializations: current.specializations,
        documents: current.documents,
      ));
    }

    try {
      final updated = await _repository.updateAvailability(isAvailable, lat: lat, lng: lng);
      state = AsyncValue.data(updated);

      // Start / stop background location tracking
      final tracker = ref.read(locationTrackerProvider);
      if (isAvailable) {
        tracker.start();
      } else {
        tracker.stop();
      }

      await _syncCacheWithAvailability(isAvailable);
    } catch (e, st) {
      if (current != null) state = AsyncValue.data(current);
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<TechnicianProfile> updateProfile({String? name, String? email, String? profilePictureUrl}) async {
    try {
      final updated = await _repository.updateProfile(
        name: name,
        email: email,
        profilePictureUrl: profilePictureUrl,
      );
      state = AsyncValue.data(updated);
      return updated;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

// ── Availability toggle (simple bool, used on dashboard) ─────────
final availabilityProvider = Provider<bool>((ref) {
  return ref.watch(profileProvider).value?.isAvailable ?? false;
});
