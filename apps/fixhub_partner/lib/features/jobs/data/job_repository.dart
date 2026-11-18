import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import '../domain/job_models.dart';

final jobRepositoryProvider = Provider<JobRepository>((ref) {
  return JobRepository(ref.read(dioProvider));
});

class JobRepository {
  final Dio _dio;

  JobRepository(this._dio);

  /// GET /technicians/jobs/current
  Future<Job?> getCurrentJob() async {
    final response = await _dio.get(ApiEndpoints.technicianCurrentJob);
    final data = _unwrap(response.data);
    if (data == null) return null;
    return Job.fromJson(data);
  }

  /// GET /technicians/jobs?status=...&page=...
  Future<PaginatedJobs> listJobs({
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _dio.get(
      ApiEndpoints.technicianJobs,
      queryParameters: {
        if (status != null) 'status': status,
        'page': page,
        'limit': limit,
      },
    );
    return PaginatedJobs.fromJson(_unwrapMap(response.data));
  }

  /// GET /technicians/jobs/history
  Future<PaginatedJobs> listJobHistory({int page = 1, int limit = 20}) async {
    final response = await _dio.get(
      ApiEndpoints.technicianJobHistory,
      queryParameters: {'page': page, 'limit': limit},
    );
    return PaginatedJobs.fromJson(_unwrapMap(response.data));
  }

  /// GET /technicians/jobs/:id
  Future<Job> getJobDetails(String id) async {
    final response = await _dio.get(ApiEndpoints.technicianJobDetails(id));
    return Job.fromJson(_unwrapMap(response.data));
  }

  /// PATCH /technicians/jobs/:id/accept
  Future<Job> acceptJob(String id) async {
    final response = await _dio.patch(ApiEndpoints.technicianJobAccept(id));
    return Job.fromJson(_unwrapMap(response.data));
  }

  /// PATCH /technicians/jobs/:id/reject
  Future<void> rejectJob(String id, String reason) async {
    await _dio.patch(
      ApiEndpoints.technicianJobReject(id),
      data: {'reason': reason},
    );
  }

  /// PATCH /technicians/jobs/:id/status
  Future<Job> updateJobStatus(
    String id,
    String status, {
    String? note,
    double? latitude,
    double? longitude,
    String? failureReason,
    String? otp,
  }) async {
    final response = await _dio.patch(
      ApiEndpoints.technicianJobStatus(id),
      data: {
        'status': status,
        if (note != null) 'note': note,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (failureReason != null) 'failureReason': failureReason,
        if (otp != null) 'otp': otp,
      },
    );
    return Job.fromJson(_unwrapMap(response.data));
  }

  /// PATCH /technicians/jobs/:id/additional-charge
  Future<Job> requestAdditionalCharge(
    String id, {
    required double amount,
    String? description,
    String? reason,
  }) async {
    final response = await _dio.patch(
      ApiEndpoints.technicianJobAdditionalCharge(id),
      data: {
        'amount': amount,
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
        if (reason != null && reason.trim().isNotEmpty)
          'reason': reason.trim(),
      },
    );
    return Job.fromJson(_unwrapMap(response.data));
  }

  /// PATCH /technicians/jobs/:id/propose-revision
  Future<Job> proposeRevision(String id, double revisedAmount, {String? note}) async {
    final response = await _dio.patch(
      ApiEndpoints.technicianJobProposeRevision(id),
      data: {
        'revisedAmount': revisedAmount.toStringAsFixed(2),
        if (note != null) 'note': note,
      },
    );
    return Job.fromJson(_unwrapMap(response.data));
  }

  dynamic _unwrap(dynamic data) {
    if (data is Map<String, dynamic>) {
      if (data.containsKey('data')) {
        final inner = data['data'];
        if (inner is Map<String, dynamic> && inner.containsKey('booking')) {
          return inner['booking'];
        }
        return inner;
      }
      if (data.containsKey('booking')) {
        return data['booking'];
      }
    }
    return data;
  }

  Map<String, dynamic> _unwrapMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      if (data.containsKey('data')) {
        final inner = data['data'];
        if (inner is Map<String, dynamic>) {
          if (inner.containsKey('booking') && inner['booking'] is Map<String, dynamic>) {
            return inner['booking'] as Map<String, dynamic>;
          }
          return inner;
        }
      }
      if (data.containsKey('booking') && data['booking'] is Map<String, dynamic>) {
        return data['booking'] as Map<String, dynamic>;
      }
      return data;
    }
    return {};
  }
}
