import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/dio_client.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.read(dioProvider));
});

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic>? data;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    required this.createdAt,
    this.data,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        type: json['type'] as String? ?? 'SYSTEM',
        isRead: json['isRead'] as bool? ?? false,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
            : DateTime.now(),
        data: json['data'] is Map ? Map<String, dynamic>.from(json['data'] as Map) : null,
      );
}

class NotificationRepository {
  final Dio _dio;

  NotificationRepository(this._dio);

  Future<List<AppNotification>> listNotifications({int page = 1, int limit = 30}) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.notifications,
        queryParameters: {'page': page, 'limit': limit},
      );
      final rawList = _extractList(response.data);
      return rawList
          .whereType<Map>()
          .map((i) => AppNotification.fromJson(Map<String, dynamic>.from(i)))
          .toList();
    } catch (e) {
      debugPrint('[NotificationRepository] listNotifications error: $e');
      rethrow;
    }
  }

  Future<void> markAsRead(String id) async {
    await _dio.patch(ApiEndpoints.notificationRead(id));
  }

  Future<void> markAllAsRead() async {
    await _dio.patch(ApiEndpoints.notificationReadAll);
  }

  Future<void> deleteNotification(String id) async {
    await _dio.delete(ApiEndpoints.notificationDelete(id));
  }

  Future<void> deleteAllNotifications() async {
    await _dio.delete(ApiEndpoints.notifications);
  }

  List<dynamic> _extractList(dynamic data) {
    if (data is Map) {
      final inner = data['data'] ?? data['items'];
      if (inner is Map) {
        final nested = inner['data'] ?? inner['items'];
        if (nested is List) return nested;
      } else if (inner is List) {
        return inner;
      }
      if (data.containsKey('data') && data['data'] is List) {
        return data['data'] as List<dynamic>;
      }
      if (data.containsKey('items') && data['items'] is List) {
        return data['items'] as List<dynamic>;
      }
    } else if (data is List) {
      return data;
    }
    return [];
  }
}
