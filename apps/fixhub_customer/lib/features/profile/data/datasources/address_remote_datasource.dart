import 'package:dio/dio.dart';
import '../../../../core/network/api_endpoints.dart';

class AddressRemoteDataSource {
  final Dio _dio;

  AddressRemoteDataSource(this._dio);

  Future<List<dynamic>> getAddresses() async {
    final response = await _dio.get(ApiEndpoints.customerAddresses);
    final raw = response.data;
    if (raw is Map && raw['data'] is List) {
      return raw['data'] as List<dynamic>;
    } else if (raw is List) {
      return raw;
    }
    return <dynamic>[];
  }

  Future<Map<String, dynamic>> addAddress(Map<String, dynamic> data) async {
    final response = await _dio.post(ApiEndpoints.customerAddresses, data: data);
    final raw = response.data;
    if (raw is Map && raw['data'] is Map) {
      return Map<String, dynamic>.from(raw['data'] as Map);
    } else if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> updateAddress(String id, Map<String, dynamic> data) async {
    final response = await _dio.patch(ApiEndpoints.customerAddress(id), data: data);
    final raw = response.data;
    if (raw is Map && raw['data'] is Map) {
      return Map<String, dynamic>.from(raw['data'] as Map);
    } else if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return <String, dynamic>{};
  }

  Future<void> deleteAddress(String id) async {
    await _dio.delete(ApiEndpoints.customerAddress(id));
  }

  Future<Map<String, dynamic>> setDefaultAddress(String id) async {
    final response = await _dio.patch(ApiEndpoints.customerAddressDefault(id));
    final raw = response.data;
    if (raw is Map && raw['data'] is Map) {
      return Map<String, dynamic>.from(raw['data'] as Map);
    } else if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return <String, dynamic>{};
  }
}
