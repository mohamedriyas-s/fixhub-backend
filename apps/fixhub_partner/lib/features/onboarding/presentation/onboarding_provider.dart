import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/onboarding_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../../../core/services/location_service.dart';
import 'package:geocoding/geocoding.dart' as geo;

// ── Catalog categories ────────────────────────────────────────────
final catalogCategoriesProvider =
    FutureProvider<List<CatalogCategory>>((ref) async {
  return ref.read(onboardingRepositoryProvider).fetchCategories();
});

// ── Sub-services for a given category ────────────────────────────
final catalogServicesProvider =
    FutureProvider.family<List<CatalogService>, String?>((ref, categoryId) async {
  return ref
      .read(onboardingRepositoryProvider)
      .fetchServices(categoryId: categoryId);
});

// ── Location Auto-Detect ─────────────────────────────────────────
final locationAutoDetectProvider = FutureProvider.autoDispose<Map<String, String>?>((ref) async {
  final locService = ref.read(locationServiceProvider);
  final position = await locService.getCurrentPosition();
  if (position == null) return null;

  try {
    final placemarks = await geo.Geocoding().placemarkFromCoordinates(position.latitude, position.longitude);
    if (placemarks.isNotEmpty) {
      final p = placemarks.first;
      if (p.postalCode != null && p.postalCode!.isNotEmpty) {
        return {
          'name': p.locality ?? p.subLocality ?? p.administrativeArea ?? 'Detected Location',
          'pincode': p.postalCode!,
        };
      }
    }
  } catch (_) {}
  return null;
});

// ── Setup wizard state ────────────────────────────────────────────
class SetupWizardState {
  final int step; // 0, 1, 2
  final String? name;
  final String? phone;
  final String? email;
  final String? selectedCategoryId;
  final List<String> selectedSubServiceIds;
  final List<Map<String, String>> customAreas;
  final bool isSubmitting;
  final String? error;

  const SetupWizardState({
    this.step = 0,
    this.name,
    this.phone,
    this.email,
    this.selectedCategoryId,
    this.selectedSubServiceIds = const [],
    this.customAreas = const [],
    this.isSubmitting = false,
    this.error,
  });

  SetupWizardState copyWith({
    int? step,
    String? name,
    String? phone,
    String? email,
    String? selectedCategoryId,
    List<String>? selectedSubServiceIds,
    List<Map<String, String>>? customAreas,
    bool? isSubmitting,
    String? error,
  }) {
    return SetupWizardState(
      step: step ?? this.step,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
      selectedSubServiceIds:
          selectedSubServiceIds ?? this.selectedSubServiceIds,
      customAreas: customAreas ?? this.customAreas,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error,
    );
  }
}

final setupWizardProvider =
    NotifierProvider.autoDispose<SetupWizardNotifier, SetupWizardState>(
        SetupWizardNotifier.new);

class SetupWizardNotifier extends Notifier<SetupWizardState> {
  @override
  SetupWizardState build() => const SetupWizardState();

  void reset() => state = const SetupWizardState();

  void setName(String name) =>
      state = state.copyWith(name: name, error: null);

  void setPhone(String phone) =>
      state = state.copyWith(phone: phone, error: null);

  void setEmail(String email) =>
      state = state.copyWith(email: email, error: null);

  void setCategory(String? categoryId) =>
      state = state.copyWith(
        selectedCategoryId: categoryId,
        selectedSubServiceIds: [], // reset on category change
        error: null,
      );

  void toggleSubService(String id) {
    final current = List<String>.from(state.selectedSubServiceIds);
    if (current.contains(id)) {
      current.remove(id);
    } else {
      current.add(id);
    }
    state = state.copyWith(selectedSubServiceIds: current, error: null);
  }

  void addCustomArea(String name, String pincode) {
    final current = List<Map<String, String>>.from(state.customAreas);
    if (!current.any((a) => a['pincode'] == pincode)) {
      current.add({'name': name, 'pincode': pincode});
    }
    state = state.copyWith(customAreas: current, error: null);
  }

  void removeCustomArea(String pincode) {
    final current = List<Map<String, String>>.from(state.customAreas);
    current.removeWhere((a) => a['pincode'] == pincode);
    state = state.copyWith(customAreas: current, error: null);
  }

  void nextStep() {
    if (state.step < 2) state = state.copyWith(step: state.step + 1);
  }

  void prevStep() {
    if (state.step > 0) state = state.copyWith(step: state.step - 1);
  }

  bool validateCurrentStep() {
    switch (state.step) {
      case 0:
        if (state.name == null || state.name!.trim().isEmpty) {
          state = state.copyWith(error: 'Please enter your full name');
          return false;
        }
        final rawPhone = (state.phone ?? '').trim().replaceAll(RegExp(r'[\s\-]'), '');
        if (rawPhone.isEmpty ||
            !RegExp(r'^(\+91|91|0)?[6-9]\d{9}$').hasMatch(rawPhone)) {
          state = state.copyWith(
              error: 'Please enter a valid 10-digit contact phone number');
          return false;
        }
        return true;
      case 1:
        if (state.selectedSubServiceIds.isEmpty) {
          state = state.copyWith(
              error: 'Please select at least one service you offer');
          return false;
        }
        return true;
      case 2:
        if (state.customAreas.isEmpty) {
          state = state.copyWith(
              error: 'Please add at least one service area');
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  /// Submit all 3 steps to the backend
  Future<void> submit() async {
    state = state.copyWith(isSubmitting: true, error: null);
    try {
      final repo = ref.read(profileRepositoryProvider);

      // Step 1: Update profile (name + phone + email)
      await repo.updateProfile(
        name: state.name?.trim(),
        phone: state.phone?.trim().isEmpty == true ? null : state.phone?.trim(),
        email: state.email?.trim().isEmpty == true ? null : state.email?.trim(),
      );

      // Step 2: Update specializations
      if (state.selectedSubServiceIds.isNotEmpty) {
        await repo.updateSpecializations(state.selectedSubServiceIds);
      }

      // Step 3: Update service areas
      if (state.customAreas.isNotEmpty) {
        await repo.updateServiceAreas(customAreas: state.customAreas);
      }

      state = state.copyWith(isSubmitting: false);
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        error: 'Something went wrong. Please try again.',
      );
      rethrow;
    }
  }
}
