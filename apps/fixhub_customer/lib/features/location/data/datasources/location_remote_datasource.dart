import 'package:dio/dio.dart';
import '../../../../core/network/api_endpoints.dart';

class LocationRemoteDataSource {
  LocationRemoteDataSource(this._dio)
      : _publicClient = Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 4),
            receiveTimeout: const Duration(seconds: 4),
          ),
        );

  final Dio _dio;
  final Dio _publicClient;

  Future<Map<String, dynamic>> validateServiceArea(String pincode, {double? lat, double? lng}) async {
    final data = <String, dynamic>{'pincode': pincode};
    if (lat != null) data['latitude'] = lat;
    if (lng != null) data['longitude'] = lng;

    final response = await _dio.post(
      ApiEndpoints.validateServiceArea,
      data: data,
    );
    return response.data;
  }

  Future<Map<String, dynamic>> requestCoverage(Map<String, dynamic> data) async {
    final response = await _dio.post(
      ApiEndpoints.requestCoverage,
      data: data,
    );
    return response.data;
  }

  /// Fast public Indian Postal Pincode directory lookup (official, no API key required)
  Future<Map<String, String>?> lookupPostalPincode(String pincode) async {
    try {
      final response = await _publicClient.get(
        'https://api.postalpincode.in/pincode/$pincode',
      );
      if (response.statusCode == 200 &&
          response.data is List &&
          (response.data as List).isNotEmpty) {
        final first = response.data[0];
        if (first['Status'] == 'Success' &&
            first['PostOffice'] is List &&
            (first['PostOffice'] as List).isNotEmpty) {
          final postOffices = (first['PostOffice'] as List)
              .whereType<Map<String, dynamic>>()
              .toList();
          if (postOffices.isEmpty) return null;

          // Prefer a Delivery post office if available, otherwise take the first
          final po = postOffices.firstWhere(
            (p) => p['DeliveryStatus']?.toString().toLowerCase() == 'delivery',
            orElse: () => postOffices.first,
          );

          final name = po['Name']?.toString().trim() ?? '';
          final district = po['District']?.toString().trim() ?? '';
          final state = po['State']?.toString().trim() ?? '';
          final pin = (po['Pincode']?.toString().trim().isNotEmpty ?? false)
              ? po['Pincode']!.toString().trim()
              : pincode;

          // Format: name, district, state, pincode
          final locationParts = [name, district, state, pin]
              .where((s) => s.isNotEmpty && s.toUpperCase() != 'NA')
              .toList();
          final formattedLocation =
              locationParts.isNotEmpty ? locationParts.join(', ') : pin;

          return {
            'name': name,
            'district': district,
            'state': state,
            'pincode': pin,
            'city': formattedLocation,
          };
        }
      }
    } catch (_) {
      // Non-blocking fallback to geocoding
    }
    return null;
  }
}
