import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../../../core/network/dio_client.dart';

final profileUploadServiceProvider = Provider<ProfileUploadService>((ref) {
  return ProfileUploadService(ref.read(dioProvider));
});

/// Handles the full profile media flow for FixHub:
///
/// Profile avatar upload (two-step presigned S3 flow):
///   1. POST /users/profile-image { fileName, contentType } → { uploadUrl, key }
///   2. PUT <uploadUrl> with raw bytes (no auth)
///   3. POST /users/profile-image { fileName, contentType, imageUrl: publicUrl }
///      → backend persists the URL on the Customer record
///
/// Profile text update:
///   PATCH /users/me { name?, email? }
class ProfileUploadService {
  ProfileUploadService(this._dio);

  final Dio _dio;

  /// Uploads [imageFile] to S3 and updates the user's profile picture.
  /// Returns the public URL of the newly uploaded avatar.
  Future<String> uploadProfileImage(File imageFile) async {
    final fileName = p.basename(imageFile.path);
    final sizeBytes = await imageFile.length();
    final ext = p.extension(fileName).toLowerCase().replaceAll('.', '');
    final contentType = _contentType(ext);

    // ── Step 1: Get presigned upload URL ─────────────────────────────
    final prepResp = await _dio.post(
      '/users/profile-image',
      data: {
        'fileName': fileName,
        'contentType': contentType,
      },
    );
    final prepData = _unwrap(prepResp.data);
    final uploadUrl = prepData['uploadUrl'] as String;
    final s3Key = prepData['key'] as String;

    // ── Step 2: PUT file directly to S3 (no JWT header) ──────────────
    final rawDio = Dio();
    await rawDio.put(
      uploadUrl,
      data: imageFile.openRead(),
      options: Options(
        headers: {
          'Content-Type': contentType,
          'Content-Length': sizeBytes,
        },
      ),
    );

    // ── Step 3: Derive public URL and persist on the customer record ──
    // The backend StorageService generates keys like:
    //   profile-images/{userId}/{timestamp}-{random}.{ext}
    // The S3 bucket is public (or CDN-fronted). We construct the URL:
    final publicUrl = _buildPublicUrl(s3Key);

    // Re-call profile-image endpoint with imageUrl — this triggers the
    // backend to update customer.profilePictureUrl in the database.
    await _dio.post(
      '/users/profile-image',
      data: {
        'fileName': fileName,
        'contentType': contentType,
        'imageUrl': publicUrl,
      },
    );

    return publicUrl;
  }

  /// Updates the user's name and/or email via PATCH /users/me.
  Future<void> updateProfile({String? name, String? email, String? phone}) async {
    final data = <String, dynamic>{};
    if (name != null && name.trim().isNotEmpty) data['name'] = name.trim();
    if (email != null && email.trim().isNotEmpty) data['email'] = email.trim();
    if (phone != null && phone.trim().isNotEmpty) data['phone'] = phone.trim();
    if (data.isEmpty) return;

    await _dio.patch('/users/me', data: data);
  }

  String _contentType(String ext) => switch (ext) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };

  // The S3 bucket for FixHub is "fixhub-uploads" (from StorageService config)
  String _buildPublicUrl(String s3Key) =>
      'https://fixhub-uploads.s3.ap-south-1.amazonaws.com/$s3Key';

  Map<String, dynamic> _unwrap(dynamic data) {
    if (data is Map<String, dynamic> && data.containsKey('data')) {
      return data['data'] as Map<String, dynamic>;
    }
    return data as Map<String, dynamic>;
  }
}
