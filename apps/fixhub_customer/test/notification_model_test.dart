import 'package:flutter_test/flutter_test.dart';
import 'package:fixhub_customer/features/notifications/data/models/notification_model.dart';

void main() {
  group('NotificationModel Deserialization Tests', () {
    test('deserializes complex backend notification json with nested payload safely', () {
      final raw = {
        'id': 'aa30cadb-d7c1-455e-99d8-a11c76ad8913',
        'userId': 'e14c7674-89c8-4060-af24-7b955fb30014',
        'title': '🔍 Finding You a Technician',
        'body': 'We are still looking for the best technician.',
        'type': 'BOOKING_UPDATE',
        'data': {
          'payload': {
            'screen': 'booking_detail',
            'bookingId': '941c3a7d-92c5-424d-8980-9d409b1144d7',
          },
          'channels': ['PUSH'],
          'deliveryLogs': [
            {
              'error': 'NO_ACTIVE_DEVICE_TOKENS',
              'status': 'SKIPPED',
              'channel': 'PUSH',
              'attemptedAt': '2026-11-23T08:55:00.077Z',
            }
          ],
        },
        'isRead': false,
        'createdAt': '2026-11-23T08:55:00.071Z',
      };

      final model = NotificationModel.fromJson(raw);
      expect(model.id, equals('aa30cadb-d7c1-455e-99d8-a11c76ad8913'));
      expect(model.title, equals('🔍 Finding You a Technician'));
      expect(model.isRead, isFalse);
      expect(model.data, isNotNull);
      expect(model.data!['payload']['bookingId'], equals('941c3a7d-92c5-424d-8980-9d409b1144d7'));
    });

    test('handles missing or malformed fields gracefully without throwing', () {
      final incomplete = <String, dynamic>{
        'id': 'test-id',
      };

      final model = NotificationModel.fromJson(incomplete);
      expect(model.id, equals('test-id'));
      expect(model.title, equals(''));
      expect(model.body, equals(''));
      expect(model.type, equals('SYSTEM'));
      expect(model.isRead, isFalse);
      expect(model.data, isNull);
      expect(model.createdAt, isA<DateTime>());
    });
  });
}
