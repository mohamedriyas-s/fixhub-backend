import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/dio_client.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.read(dioProvider));
});

class TechnicianProfile {
  final String id;
  final bool isAvailable;
  final String verificationStatus;
  final double rating;
  final int totalJobs;
  final String? profilePictureUrl;
  final String? name;
  final String? phone;
  final String? email;
  final List<dynamic> serviceAreas;
  final List<dynamic> specializations;
  final List<dynamic> documents;

  const TechnicianProfile({
    required this.id,
    required this.isAvailable,
    required this.verificationStatus,
    required this.rating,
    required this.totalJobs,
    this.profilePictureUrl,
    this.name,
    this.phone,
    this.email,
    this.serviceAreas = const [],
    this.specializations = const [],
    this.documents = const [],
  });

  factory TechnicianProfile.fromJson(Map<String, dynamic> json) {
    final rawUser = json['user'];
    final user = rawUser is Map ? Map<String, dynamic>.from(rawUser) : null;
    return TechnicianProfile(
      id: json['id']?.toString() ?? '',
      isAvailable: json['isAvailable'] as bool? ?? false,
      verificationStatus: json['verificationStatus'] as String? ?? 'PENDING',
      rating: double.tryParse(json['rating']?.toString() ?? '') ?? 0.0,
      totalJobs: int.tryParse(json['totalJobs']?.toString() ?? '') ?? 0,
      profilePictureUrl: json['profilePictureUrl'] as String?,
      name: user?['name'] as String?,
      phone: user?['phone'] as String?,
      email: user?['email'] as String?,
      serviceAreas: (json['serviceAreas'] as List<dynamic>?) ?? const [],
      specializations: (json['specializations'] as List<dynamic>?) ?? const [],
      documents: (json['documents'] as List<dynamic>?) ?? const [],
    );
  }

  String get displayName => name ?? phone ?? 'Technician';
  bool get isVerified => verificationStatus == 'VERIFIED';

  /// Profile is considered complete when the technician has set a name,
  /// selected at least one specialization, and at least one service area.
  bool get isProfileComplete =>
      isVerified ||
      ((name?.isNotEmpty ?? false) &&
          specializations.isNotEmpty &&
          serviceAreas.isNotEmpty);
}

class ProfileRepository {
  final Dio _dio;

  ProfileRepository(this._dio);

  Future<TechnicianProfile> getProfile() async {
    final response = await _dio.get(ApiEndpoints.technicianProfile);
    return TechnicianProfile.fromJson(unwrapMap(response.data));
  }

  Future<TechnicianProfile> updateAvailability(
    bool isAvailable, {
    double? lat,
    double? lng,
  }) async {
    final response = await _dio.patch(
      ApiEndpoints.technicianAvailability,
      data: {
        'isAvailable': isAvailable,
        if (lat != null) 'latitude': lat,
        if (lng != null) 'longitude': lng,
      },
    );
    return TechnicianProfile.fromJson(unwrapMap(response.data));
  }

  Future<TechnicianProfile> updateProfile({
    String? name,
    String? email,
    String? profilePictureUrl,
  }) async {
    final response = await _dio.put(
      ApiEndpoints.technicianProfile,
      data: {
        if (name != null) 'name': name,
        if (email != null) 'email': email,
        if (profilePictureUrl != null) 'profilePictureUrl': profilePictureUrl,
      },
    );
    return TechnicianProfile.fromJson(unwrapMap(response.data));
  }

  Future<void> updateLocation(double latitude, double longitude) async {
    await _dio.patch(
      ApiEndpoints.technicianLocation,
      data: {'latitude': latitude, 'longitude': longitude},
    );
  }

  Future<void> pingHeartbeat() async {
    try {
      await _dio.post(ApiEndpoints.technicianHeartbeat);
    } catch (_) {}
  }

  /// PUT /technicians/specializations — replaces existing specializations
  Future<void> updateSpecializations(List<String> subServiceIds) async {
    await _dio.put(
      ApiEndpoints.technicianSpecializations,
      data: {'subServiceIds': subServiceIds},
    );
  }

  /// PUT /technicians/service-areas — syncs service areas
  Future<void> updateServiceAreas({List<String>? areaIds, List<Map<String, String>>? customAreas}) async {
    final data = <String, dynamic>{};
    if (areaIds != null && areaIds.isNotEmpty) data['serviceAreaIds'] = areaIds;
    if (customAreas != null && customAreas.isNotEmpty) data['customAreas'] = customAreas;
    
    await _dio.put(
      ApiEndpoints.technicianServiceAreas,
      data: data,
    );
  }

  /// GET /technicians/specializations
  Future<List<dynamic>> getSpecializations() async {
    final response = await _dio.get(ApiEndpoints.technicianSpecializations);
    final data = unwrap(response.data);
    if (data is List) return data;
    return [];
  }

  /// GET /technicians/service-areas
  Future<List<dynamic>> getServiceAreas() async {
    final response = await _dio.get(ApiEndpoints.technicianServiceAreas);
    final data = unwrap(response.data);
    if (data is List) return data;
    return [];
  }

  dynamic unwrap(dynamic data) {
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      if (map.containsKey('data')) {
        return map['data'];
      }
      return map;
    }
    return data;
  }

  Map<String, dynamic> unwrapMap(dynamic data) {
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      if (map.containsKey('data') && map['data'] is Map) {
        return Map<String, dynamic>.from(map['data'] as Map);
      }
      return map;
    }
    return <String, dynamic>{};
  }
}
