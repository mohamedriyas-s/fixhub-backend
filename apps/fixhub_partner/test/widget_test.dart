import 'package:flutter_test/flutter_test.dart';
import 'package:fixhub_partner/features/auth/domain/auth_state.dart';

void main() {
  test('AuthUser serialization smoke test', () {
    const json = {
      'id': 'tech-123',
      'phone': '+919876543210',
      'role': 'TECHNICIAN',
      'profile': {
        'profilePictureUrl': null,
        'verificationStatus': 'VERIFIED',
      },
    };

    final user = AuthUser.fromJson(json);
    expect(user.id, 'tech-123');
    expect(user.isVerified, true);
  });
}
