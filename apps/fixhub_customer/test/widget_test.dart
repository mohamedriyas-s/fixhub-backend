import 'package:flutter_test/flutter_test.dart';
import 'package:fixhub_customer/features/auth/data/models/auth_response_model.dart';

void main() {
  test('AuthResponseModel serialization smoke test', () {
    const json = {
      'accessToken': 'dummy_access_token',
      'refreshToken': 'dummy_refresh_token',
      'isNewUser': false,
      'user': {
        'id': 'user-123',
        'phone': '+919876543210',
        'role': 'CUSTOMER',
        'customer': {
          'id': 'cust-123',
          'profilePictureUrl': null,
        },
      },
    };

    final authResponse = AuthResponseModel.fromJson(json);
    expect(authResponse.accessToken, 'dummy_access_token');
    expect(authResponse.user.id, 'user-123');
    expect(authResponse.user.profile?.id, 'cust-123');

    final serialized = authResponse.user.toJson();
    expect(serialized['customer'], isA<Map<String, dynamic>>());
  });
}
