import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:fixhub_partner/features/profile/data/profile_repository.dart';

void main() {
  group('TechnicianProfile Deserialization Tests', () {
    test('parses backend profile response with dynamic maps correctly', () {
      final backendResponse = <dynamic, dynamic>{
        'success': true,
        'data': <dynamic, dynamic>{
          'id': '02494180-dc15-4734-8c6d-affd4e564043',
          'userId': 'edb871a1-fe08-46c8-97fc-e0c5d1040f06',
          'profilePictureUrl': null,
          'isAvailable': false,
          'verificationStatus': 'VERIFIED',
          'rejectionNote': null,
          'rating': '4.50',
          'totalJobs': 12,
          'latitude': '13.1363202',
          'longitude': '80.2201513',
          'user': <dynamic, dynamic>{
            'id': 'edb871a1-fe08-46c8-97fc-e0c5d1040f06',
            'phone': '+919876543219',
            'name': 'Inbaraj',
            'email': 'inba@gmail.com',
            'role': 'TECHNICIAN',
          },
          'serviceAreas': [
            {'serviceArea': {'name': 'Adyar'}},
          ],
          'specializations': [
            {
              'subService': {'name': 'AC Repair'},
            },
          ],
          'documents': [],
        },
      };

      final repo = ProfileRepository(Dio());
      final unwrapped = repo.unwrapMap(backendResponse);
      expect(unwrapped, isA<Map<String, dynamic>>());

      final profile = TechnicianProfile.fromJson(unwrapped);
      expect(profile.name, 'Inbaraj');
      expect(profile.phone, '+919876543219');
      expect(profile.email, 'inba@gmail.com');
      expect(profile.rating, 4.5);
      expect(profile.totalJobs, 12);
      expect(profile.displayName, 'Inbaraj');
      expect(profile.isVerified, true);
      expect(profile.serviceAreas.length, 1);
      expect(profile.specializations.length, 1);
    });

    test('handles missing or null user gracefully', () {
      final map = <String, dynamic>{
        'id': 'some-id',
        'isAvailable': true,
        'verificationStatus': 'PENDING',
        'rating': null,
        'totalJobs': null,
        'user': null,
      };

      final profile = TechnicianProfile.fromJson(map);
      expect(profile.id, 'some-id');
      expect(profile.name, isNull);
      expect(profile.displayName, 'Technician');
      expect(profile.rating, 0.0);
      expect(profile.totalJobs, 0);
      expect(profile.isAvailable, true);
    });
  });
}
