import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:geolocator/geolocator.dart';
import '../../data/repositories/location_repository_impl.dart';
import '../../domain/repositories/location_repository.dart';
import '../../data/datasources/location_remote_datasource.dart';
import '../../data/models/service_area_validation_model.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/local_storage.dart';

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return LocationRepositoryImpl(LocationRemoteDataSource(dio));
});

enum LocationStatus { initial, checking, valid, invalid, error }

class LocationState {
  const LocationState({
    this.status = LocationStatus.initial,
    this.currentPincode,
    this.currentCity,
    this.lastValidPincode,
    this.lastValidCity,
    this.serviceAreaResult,
    this.errorMessage,
    this.hasPermission = false,
    this.isRestoring = true,
  });

  final LocationStatus status;
  final String? currentPincode;
  final String? currentCity;
  final String? lastValidPincode;
  final String? lastValidCity;
  final ServiceAreaValidationModel? serviceAreaResult;
  final String? errorMessage;
  final bool hasPermission;
  final bool isRestoring;

  bool get hasValidLocation =>
      lastValidPincode != null && lastValidPincode!.isNotEmpty;

  LocationState copyWith({
    LocationStatus? status,
    String? currentPincode,
    String? currentCity,
    String? lastValidPincode,
    String? lastValidCity,
    ServiceAreaValidationModel? serviceAreaResult,
    String? errorMessage,
    bool clearErrorMessage = false,
    bool? hasPermission,
    bool? isRestoring,
  }) {
    return LocationState(
      status: status ?? this.status,
      currentPincode: currentPincode ?? this.currentPincode,
      currentCity: currentCity ?? this.currentCity,
      lastValidPincode: lastValidPincode ?? this.lastValidPincode,
      lastValidCity: lastValidCity ?? this.lastValidCity,
      serviceAreaResult: serviceAreaResult ?? this.serviceAreaResult,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      hasPermission: hasPermission ?? this.hasPermission,
      isRestoring: isRestoring ?? this.isRestoring,
    );
  }
}

final locationProvider = StateNotifierProvider<LocationNotifier, LocationState>((ref) {
  return LocationNotifier(
    ref.watch(locationRepositoryProvider),
    ref.watch(localStorageProvider),
  );
});

class LocationNotifier extends StateNotifier<LocationState> {
  LocationNotifier(this._repository, this._localStorage) : super(const LocationState()) {
    _init();
  }

  final LocationRepository _repository;
  final LocalStorage _localStorage;

  Future<void> _init() async {
    final hasPermission = await _repository.checkPermission();

    // Restore previously validated location
    final savedStatus = await _localStorage.getSavedLocationStatus();
    final savedPincode = await _localStorage.getSavedPincode();
    final savedCity = await _localStorage.getSavedCity();

    if (savedStatus == 'valid' && savedPincode != null) {
      state = state.copyWith(
        hasPermission: hasPermission,
        status: LocationStatus.valid,
        currentPincode: savedPincode,
        currentCity: savedCity,
        lastValidPincode: savedPincode,
        lastValidCity: savedCity,
        isRestoring: false,
        clearErrorMessage: true,
      );
    } else {
      // Clear any legacy invalid location saved in local storage
      if (savedStatus == 'invalid') {
        await _localStorage.clearLocation();
      }
      state = state.copyWith(
        hasPermission: hasPermission,
        status: LocationStatus.initial,
        isRestoring: false,
        clearErrorMessage: true,
      );
    }
  }

  Future<void> refreshPermission() async {
    final hasPermission = await _repository.checkPermission();
    if (state.hasPermission != hasPermission) {
      state = state.copyWith(hasPermission: hasPermission);
    }
  }

  void clearError() {
    if (state.status == LocationStatus.error || state.errorMessage != null) {
      state = state.copyWith(
        status: LocationStatus.initial,
        clearErrorMessage: true,
      );
    }
  }

  Future<bool> requestPermission() async {
    final granted = await _repository.requestPermission();
    state = state.copyWith(hasPermission: granted);
    return granted;
  }

  Future<void> detectFromGPS() async {
    state = state.copyWith(status: LocationStatus.checking, clearErrorMessage: true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
        state = state.copyWith(
          status: LocationStatus.error,
          errorMessage: 'Location services are disabled. Please enable GPS.',
        );
        return;
      }

      final hasPermission = await requestPermission();
      if (!hasPermission) {
        state = state.copyWith(
          status: LocationStatus.error,
          errorMessage: 'Location permission denied. Please grant permission in settings.',
        );
        return;
      }

      final position = await _repository.getCurrentLocation();
      final addressData = await _repository.getAddressFromPosition(position);

      if (addressData == null || addressData['pincode'] == null) {
        state = state.copyWith(
          status: LocationStatus.error,
          errorMessage: 'Could not determine pincode from location. Please enter manually.',
        );
        return;
      }

      final pincode = addressData['pincode']!;
      final city = addressData['city']!;

      await validateArea(pincode, lat: position.latitude, lng: position.longitude, city: city);
    } catch (e, stack) {
      debugPrint('[LocationNotifier] detectFromGPS error: $e\n$stack');
      final errString = e.toString();
      final String message;
      if (errString.contains('Location permission denied')) {
        message = 'Location permission denied. Please grant permission in settings.';
      } else if (errString.contains('Location services are disabled')) {
        message = 'Location services are disabled. Please enable GPS.';
      } else {
        message = 'Failed to detect location. Please check your connection or enter manually.';
      }
      state = state.copyWith(
        status: LocationStatus.error,
        errorMessage: message,
      );
    }
  }

  Future<void> validateManualPincode(String pincode) async {
    state = state.copyWith(status: LocationStatus.checking, clearErrorMessage: true);
    
    // 1. Retrieve address information for this pincode
    Map<String, String>? addressData;
    try {
      addressData = await _repository.getAddressFromPincode(pincode);
    } catch (e) {
      debugPrint('[LocationNotifier] Address lookup for $pincode failed: $e');
    }

    final city = addressData?['city'];
    final lat = addressData?['latitude'] != null ? double.tryParse(addressData!['latitude']!) : null;
    final lng = addressData?['longitude'] != null ? double.tryParse(addressData!['longitude']!) : null;

    // 2. Validate against FixHub service areas
    await validateArea(pincode, lat: lat, lng: lng, city: city);
  }

  Future<void> validateArea(String pincode, {double? lat, double? lng, String? city}) async {
    state = state.copyWith(status: LocationStatus.checking, clearErrorMessage: true);
    try {
      final result = await _repository.validateServiceArea(pincode, lat: lat, lng: lng);

      final displayLocation =
          (city != null && city.trim().isNotEmpty) ? city.trim() : pincode;

      if (result.isServiceable) {
        state = state.copyWith(
          status: LocationStatus.valid,
          currentPincode: pincode,
          currentCity: displayLocation,
          lastValidPincode: pincode,
          lastValidCity: displayLocation,
          serviceAreaResult: result,
          clearErrorMessage: true,
        );
        // Persist so we skip the screen next launch
        await _localStorage.saveLocation(pincode: pincode, status: 'valid', city: displayLocation);
      } else {
        state = state.copyWith(
          status: LocationStatus.invalid,
          currentPincode: pincode,
          currentCity: displayLocation,
          serviceAreaResult: result,
          clearErrorMessage: true,
        );
        // Do NOT save invalid pincode to _localStorage so it never persists as active location
      }
    } catch (e, stack) {
      debugPrint('[LocationNotifier] validateArea error: $e\n$stack');
      state = state.copyWith(
        status: LocationStatus.error,
        errorMessage: 'Unable to connect to service. Please check your internet connection.',
      );
    }
  }

  void revertToLastValidLocation() {
    if (state.lastValidPincode != null) {
      state = LocationState(
        status: LocationStatus.valid,
        currentPincode: state.lastValidPincode,
        currentCity: state.lastValidCity,
        lastValidPincode: state.lastValidPincode,
        lastValidCity: state.lastValidCity,
        hasPermission: state.hasPermission,
        isRestoring: false,
      );
    } else {
      state = LocationState(
        status: LocationStatus.initial,
        hasPermission: state.hasPermission,
        isRestoring: false,
      );
    }
  }

  void reset() {
    _localStorage.clearLocation();
    state = const LocationState();
    _init();
  }
}
