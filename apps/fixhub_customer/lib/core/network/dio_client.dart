import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/error_interceptor.dart';

/// Interceptor that automatically switches from a LAN IP (e.g. 192.168.x.x)
/// to 10.0.2.2 when running inside the Android Studio emulator if the LAN IP
/// is unreachable due to host firewall or network isolation.
class EmulatorFallbackInterceptor extends Interceptor {
  final Dio _dio;
  bool _switched = false;

  EmulatorFallbackInterceptor(this._dio);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (!kIsWeb &&
        Platform.isAndroid &&
        !_switched &&
        (err.type == DioExceptionType.connectionError ||
            err.type == DioExceptionType.connectionTimeout)) {
      final host = err.requestOptions.uri.host;
      if (host.startsWith('192.168.') || host == 'localhost' || host == '127.0.0.1') {
        _switched = true;
        try {
          final newUri = err.requestOptions.uri.replace(host: '10.0.2.2');
          debugPrint('[EmulatorFallbackInterceptor] Falling back from $host to 10.0.2.2');
          final opts = Options(
            method: err.requestOptions.method,
            headers: err.requestOptions.headers,
            responseType: err.requestOptions.responseType,
            contentType: err.requestOptions.contentType,
            receiveTimeout: err.requestOptions.receiveTimeout,
            sendTimeout: err.requestOptions.sendTimeout,
          );
          final response = await _dio.requestUri(
            newUri,
            data: err.requestOptions.data,
            options: opts,
          );
          if (_dio.options.baseUrl.contains(host)) {
            _dio.options.baseUrl = _dio.options.baseUrl.replaceFirst(host, '10.0.2.2');
          }
          return handler.resolve(response);
        } catch (_) {
          // If 10.0.2.2 also fails, pass through original error
        }
      }
    }
    handler.next(err);
  }
}

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      // Production-grade timeouts
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-Client': 'fixhub-customer/1.0.0',
      },
    ),
  );

  dio.interceptors.addAll([
    AuthInterceptor(ref),
    EmulatorFallbackInterceptor(dio),
    ErrorInterceptor(),
    // Debug logging — only in non-production; suppress noisy DioException dumps
    if (AppConfig.isDevelopment)
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        requestHeader: false,
        responseHeader: false,
        error: false,
      ),
  ]);

  return dio;
});
