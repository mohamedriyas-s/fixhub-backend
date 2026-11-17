import 'package:dio/dio.dart';
import '../../error/failures.dart';

class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    Failure failure;
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        failure = const NetworkFailure(
          message: 'Connection timed out. Please check your internet.',
        );
        break;
      case DioExceptionType.connectionError:
        failure = const NetworkFailure(message: 'No internet connection');
        break;
      case DioExceptionType.badResponse:
        failure = _mapBadResponse(err);
        break;
      case DioExceptionType.cancel:
        failure = const NetworkFailure(message: 'Request was cancelled');
        break;
      default:
        failure = ServerFailure(
          message: err.message ?? 'Something went wrong. Please try again.',
        );
        break;
    }
    handler.reject(err.copyWith(error: failure, message: failure.message));
  }

  Failure _mapBadResponse(DioException err) {
    final data = err.response?.data;
    final rawMessage = data is Map
        ? (data['message'] ?? 'Server error')
        : 'Server error';
    final message = rawMessage is List
        ? rawMessage.first.toString()
        : rawMessage.toString();
    final errorCode = data is Map ? data['errorCode']?.toString() : null;

    switch (err.response?.statusCode) {
      case 400:
        return ValidationFailure(message: message, errorCode: errorCode);
      case 401:
        return AuthFailure(message: message, errorCode: errorCode);
      case 403:
        return AuthFailure(message: 'Access denied', errorCode: errorCode);
      case 404:
        return NotFoundFailure(message: message, errorCode: errorCode);
      case 429:
        return const ServerFailure(
          message: 'Too many requests. Please wait a moment.',
        );
      default:
        return ServerFailure(message: message, errorCode: errorCode);
    }
  }
}
