import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geo;
import '../../domain/repositories/location_repository.dart';
import '../datasources/location_remote_datasource.dart';
import '../models/service_area_validation_model.dart';

class LocationRepositoryImpl implements LocationRepository {
  LocationRepositoryImpl(this._remoteDataSource);

  final LocationRemoteDataSource _remoteDataSource;

  @override
  Future<bool> checkPermission() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    final LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }
    return true;
  }

  @override
  Future<bool> requestPermission() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      return false;
    }

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      return false;
    }

    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  @override
  Future<Position> getCurrentLocation() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      throw Exception('Location permission denied');
    }
    if (permission == LocationPermission.denied) {
      throw Exception('Location permission denied');
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } catch (_) {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        return lastKnown;
      }
      rethrow;
    }
  }

  @override
  Future<Map<String, String>?> getAddressFromPosition(Position position) async {
    try {
      final placemarks = await geo.Geocoding()
          .placemarkFromCoordinates(
            position.latitude,
            position.longitude,
          )
          .timeout(const Duration(seconds: 6));
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final pincode = p.postalCode?.trim();
        if (pincode != null && pincode.isNotEmpty) {
          final localityParts = [
            p.subLocality,
            p.locality,
            p.subAdministrativeArea,
            p.administrativeArea,
          ].where((e) => e != null && e.trim().isNotEmpty).map((e) => e!.trim()).toSet();

          final city = localityParts.isNotEmpty
              ? localityParts.take(2).join(', ')
              : (p.locality ?? p.administrativeArea ?? 'Unknown Location');

          return {
            'pincode': pincode,
            'city': city,
            'latitude': position.latitude.toString(),
            'longitude': position.longitude.toString(),
          };
        }
      }
    } catch (e) {
      debugPrint('[LocationRepository] Reverse geocoding failed: $e');
    }
    return null;
  }

  @override
  Future<Map<String, String>?> getAddressFromPincode(String pincode) async {
    // 1. Try fast postal directory lookup
    final postalResult = await _remoteDataSource.lookupPostalPincode(pincode);
    if (postalResult != null && postalResult['city'] != null && postalResult['city'] != 'Unknown Location') {
      return postalResult;
    }

    // 2. Fallback to geocoding plugin
    try {
      final locations = await geo.Geocoding()
          .locationFromAddress('$pincode, India')
          .timeout(const Duration(seconds: 4));
      if (locations.isNotEmpty) {
        final loc = locations.first;
        final placemarks = await geo.Geocoding()
            .placemarkFromCoordinates(loc.latitude, loc.longitude)
            .timeout(const Duration(seconds: 4));
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final name = p.subLocality?.trim().isNotEmpty == true
              ? p.subLocality!.trim()
              : (p.locality?.trim() ?? '');
          final district = p.subAdministrativeArea?.trim().isNotEmpty == true
              ? p.subAdministrativeArea!.trim()
              : (p.locality?.trim() ?? '');
          final state = p.administrativeArea?.trim() ?? '';
          final localityParts = [name, district, state, pincode]
              .where((e) => e.isNotEmpty && e.toUpperCase() != 'NA')
              .toList();
          final city = localityParts.isNotEmpty ? localityParts.join(', ') : 'Unknown Location';
          return {
            'name': name,
            'district': district,
            'state': state,
            'pincode': pincode,
            'city': city,
            'latitude': loc.latitude.toString(),
            'longitude': loc.longitude.toString(),
          };
        }
      }
    } catch (e) {
      debugPrint('[LocationRepository] Geocoding from pincode failed: $e');
    }

    return postalResult;
  }

  @override
  Future<ServiceAreaValidationModel> validateServiceArea(String pincode, {double? lat, double? lng}) async {
    final response = await _remoteDataSource.validateServiceArea(pincode, lat: lat, lng: lng);
    final data = response['data'] ?? response;

    return ServiceAreaValidationModel.fromJson(
      Map<String, dynamic>.from(data),
    );
  }

  @override
  Future<void> requestCoverage(String pincode, String name, String phone, String email) async {
    await _remoteDataSource.requestCoverage({
      'pincode': pincode,
      'name': name,
      'phone': phone,
      'email': email,
    });
  }
}
