import 'package:flutter_test/flutter_test.dart';
import 'package:fixhub_partner/features/auth/domain/auth_state.dart';
import 'package:fixhub_partner/features/jobs/domain/job_models.dart';

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

  test('JobCustomer.fromJson handles null phone for email-OTP customers', () {
    final customer = JobCustomer.fromJson({
      'id': 'cust-1',
      'user': {
        'id': 'user-1',
        'name': null,
        'phone': null,
        'email': 'customer@example.com',
      },
    });

    expect(customer.id, 'user-1');
    expect(customer.phone, '');
    expect(customer.email, 'customer@example.com');
    expect(customer.displayName, 'customer@example.com');
  });
}
