import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final bookingMediaUploadServiceProvider =
    Provider<BookingMediaUploadService>((ref) {
  return BookingMediaUploadService(ref.read(dioProvider));
});

/// Handles the two-step presigned S3 media upload flow for booking issue photos/videos.
///
/// Flow per file:
///   1. POST /bookings/{id}/media { fileName, contentType, sizeBytes, type, uploadPhase }
///      → backend returns { uploadUrl, key }
///   2. PUT <uploadUrl> with raw bytes via a fresh Dio (no JWT — S3 must not see it)
///   3. POST /bookings/{id}/media with same params + `url: publicUrl`
///      → backend creates the BookingMedia DB record
///
/// The S3 PUT uses readAsBytes() (not openRead()) to provide an accurate Content-Length,
/// which is mandatory for pre-signed PutObject URLs.
class BookingMediaUploadService {
  BookingMediaUploadService(this._dio);

  final Dio _dio;

  // S3 bucket public base URL fallback
  static const _s3Base =
      'https://spotfluencerbucket2.s3.ap-south-1.amazonaws.com';

  /// Upload [file] for booking [bookingId].
  ///
  /// [contentType] e.g. 'image/jpeg', 'video/mp4'
  /// [phase] one of 'BEFORE_SERVICE' | 'DURING_SERVICE' | 'AFTER_SERVICE'
  ///
  /// Returns the persisted public URL of the newly created [BookingMedia] record.
  Future<String> uploadFile({
    required String bookingId,
    required File file,
    required String contentType,
    required String phase,
    void Function(int sent, int total)? onProgress,
  }) async {
    final fileName = file.path.split(Platform.pathSeparator).last;
    final Uint8List bytes = await file.readAsBytes(); // load once
    final int sizeBytes = bytes.length;
    final bool isVideo = contentType.startsWith('video/');

    // ── Step 1: Request presigned PUT URL ──────────────────────────────
    final prepResp = await _dio.post(
      ApiEndpoints.bookingMedia(bookingId),
      data: {
        'fileName': fileName,
        'contentType': contentType,
        'sizeBytes': sizeBytes,
        'type': isVideo ? 'VIDEO' : 'IMAGE',
        'uploadPhase': phase,
      },
    );

    final prepData = _unwrap(prepResp.data);
    final String uploadUrl = prepData['uploadUrl'] as String;
    final String s3Key = prepData['key'] as String;

    // ── Step 2: PUT raw bytes to S3 (no JWT, fresh Dio) ───────────────
    final rawDio = Dio();
    await rawDio.put<dynamic>(
      uploadUrl,
      data: bytes, // Uint8List — Dio sends as binary body with known length
      options: Options(
        headers: {
          'Content-Type': contentType,
          'Content-Length': sizeBytes,
        },
        // S3 returns 200; treat non-2xx as an error
        validateStatus: (status) => status != null && status < 300,
      ),
      onSendProgress: onProgress,
    );

    // ── Step 3: Persist the public URL via the backend ─────────────────
    // Derive the public S3 URL directly from the presigned upload URL (without query params)
    final String publicUrl = uploadUrl.contains('?')
        ? uploadUrl.split('?').first
        : '$_s3Base/$s3Key';

    final attachResp = await _dio.post(
      ApiEndpoints.bookingMedia(bookingId),
      data: {
        'fileName': fileName,
        'contentType': contentType,
        'sizeBytes': sizeBytes,
        'type': isVideo ? 'VIDEO' : 'IMAGE',
        'uploadPhase': phase,
        'url': publicUrl, // presence of url triggers DB record creation
      },
    );

    final attachData = _unwrap(attachResp.data);
    final media = attachData['media'];
    if (media != null && media['url'] != null) {
      return media['url'] as String;
    }
    return publicUrl;
  }

  Map<String, dynamic> _unwrap(dynamic data) {
    if (data is Map<String, dynamic> && data.containsKey('data')) {
      return data['data'] as Map<String, dynamic>;
    }
    return data as Map<String, dynamic>;
  }
}
