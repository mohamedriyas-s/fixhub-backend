import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../network/dio_client.dart';
import 'package:shimmer/shimmer.dart';
import '../config/theme/app_colors.dart';

/// A family provider that fetches and caches presigned S3 URLs.
/// Caches based on the original URL to prevent redundant API calls.
final presignedUrlProvider = FutureProvider.family<String, String>((ref, originalUrl) async {
  if (!originalUrl.contains('fixhub-uploads.s3')) {
    // If it's not a HelpTab S3 URL, just return it as is.
    return originalUrl;
  }
  
  final dio = ref.read(dioProvider);
  try {
    final response = await dio.get('/users/presigned-get-url', queryParameters: {'url': originalUrl});
    if (response.data != null && response.data['data'] != null) {
      return response.data['data']['downloadUrl'] as String;
    }
    return originalUrl; // Fallback to original
  } catch (e) {
    // Return original on error and let Image.network handle the 403
    return originalUrl;
  }
});

/// A smart network image widget that automatically resolves private S3 URLs 
/// into short-lived presigned GET URLs before rendering.
class FixHubNetworkImage extends ConsumerWidget {
  const FixHubNetworkImage(
    this.url, {
    super.key,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.errorBuilder,
    this.placeholderBuilder,
  });

  final String? url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final ImageErrorWidgetBuilder? errorBuilder;
  final WidgetBuilder? placeholderBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (url == null || url!.isEmpty) {
      return _buildError(context, null, null);
    }

    final presignedUrlAsync = ref.watch(presignedUrlProvider(url!));

    return presignedUrlAsync.when(
      data: (resolvedUrl) {
        return Image.network(
          resolvedUrl,
          fit: fit,
          width: width,
          height: height,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _buildPlaceholder(context);
          },
          errorBuilder: (context, error, stackTrace) =>
              _buildError(context, error, stackTrace),
        );
      },
      loading: () => _buildPlaceholder(context),
      error: (err, stack) => _buildError(context, err, stack),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    if (placeholderBuilder != null) {
      return placeholderBuilder!(context);
    }
    return Shimmer.fromColors(
      baseColor: AppColors.surface,
      highlightColor: Colors.white,
      child: Container(
        width: width ?? double.infinity,
        height: height ?? double.infinity,
        color: AppColors.surface,
      ),
    );
  }

  Widget _buildError(BuildContext context, Object? error, StackTrace? stackTrace) {
    if (errorBuilder != null) {
      return errorBuilder!(context, error ?? Exception('Empty URL'), stackTrace);
    }
    return Container(
      width: width,
      height: height,
      color: AppColors.surface,
      child: const Center(
        child: Icon(Icons.broken_image_rounded, color: AppColors.textSecondary),
      ),
    );
  }
}
