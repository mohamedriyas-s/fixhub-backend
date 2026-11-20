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
          final po = first['PostOffice'][0] as Map<String, dynamic>;
          final district = po['District']?.toString() ?? '';
          final block = po['Block']?.toString() ?? po['Name']?.toString() ?? '';
          final state = po['State']?.toString() ?? '';
          final cityParts = [block, district]
              .where((s) => s.isNotEmpty && s.toUpperCase() != 'NA')
              .toSet();
          final city = cityParts.isNotEmpty ? cityParts.join(', ') : district;
          return {
            'pincode': pincode,
            'city': city.isNotEmpty ? city : 'Unknown Location',
            'state': state,
          };
        }
      }
    } catch (_) {
      // Non-blocking fallback to geocoding
    }
    return null;
  }
}
