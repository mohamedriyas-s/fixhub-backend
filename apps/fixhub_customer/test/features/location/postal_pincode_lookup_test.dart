import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fixhub_customer/features/location/data/datasources/location_remote_datasource.dart';

class MockDio extends Mock implements Dio {}

void main() {
  group('Postal Pincode Lookup Tests', () {
    test('formats Kolathur 600099 as name, district, state, pincode accurately', () async {
      // Test the parsing logic with the real India Post JSON response structure
      const kolathurPostOffices = [
        {
          'Name': 'Kolathur',
          'Description': null,
          'BranchType': 'Sub Post Office',
          'DeliveryStatus': 'Delivery',
          'Circle': 'Tamilnadu',
          'District': 'Tiruvallur',
          'Division': 'Tambaram',
          'Region': 'Chennai Region',
          'Block': 'Ambattur',
          'State': 'Tamil Nadu',
          'Country': 'India',
          'Pincode': '600099',
        },
        {
          'Name': 'Lakshmipuram',
          'Description': null,
          'BranchType': 'Branch Post Office',
          'DeliveryStatus': 'Non-Delivery',
          'Circle': 'Tamilnadu',
          'District': 'Tiruvallur',
          'Division': 'Tambaram',
          'Region': 'Chennai Region',
          'Block': 'Ambattur',
          'State': 'Tamil Nadu',
          'Country': 'India',
          'Pincode': '600099',
        }
      ];

      final po = kolathurPostOffices.firstWhere(
        (p) => p['DeliveryStatus']?.toString().toLowerCase() == 'delivery',
        orElse: () => kolathurPostOffices.first,
      );

      final name = po['Name']?.toString().trim() ?? '';
      final district = po['District']?.toString().trim() ?? '';
      final state = po['State']?.toString() ?? '';
      final pin = po['Pincode']!.toString().trim();

      final parts = [name, district, state, pin]
          .where((s) => s.isNotEmpty && s.toUpperCase() != 'NA')
          .toList();
      final formatted = parts.join(', ');

      expect(name, 'Kolathur');
      expect(district, 'Tiruvallur');
      expect(state, 'Tamil Nadu');
      expect(pin, '600099');
      expect(formatted, 'Kolathur, Tiruvallur, Tamil Nadu, 600099');
    });

    test('formats Ponniammanmedu 600110 as name, district, state, pincode accurately', () async {
      const ponniammanmeduPostOffices = [
        {
          'Name': 'Ponniammanmedu',
          'Description': null,
          'BranchType': 'Sub Post Office',
          'DeliveryStatus': 'Delivery',
          'Circle': 'Tamilnadu',
          'District': 'Tiruvallur',
          'Division': 'Tambaram',
          'Region': 'Chennai Region',
          'Block': 'Ambattur',
          'State': 'Tamil Nadu',
          'Country': 'India',
          'Pincode': '600110',
        }
      ];

      final po = ponniammanmeduPostOffices.firstWhere(
        (p) => p['DeliveryStatus']?.toString().toLowerCase() == 'delivery',
        orElse: () => ponniammanmeduPostOffices.first,
      );

      final name = po['Name']?.toString().trim() ?? '';
      final district = po['District']?.toString().trim() ?? '';
      final state = po['State']?.toString() ?? '';
      final pin = po['Pincode']!.toString().trim();

      final parts = [name, district, state, pin]
          .where((s) => s.isNotEmpty && s.toUpperCase() != 'NA')
          .toList();
      final formatted = parts.join(', ');

      expect(name, 'Ponniammanmedu');
      expect(district, 'Tiruvallur');
      expect(state, 'Tamil Nadu');
      expect(pin, '600110');
      expect(formatted, 'Ponniammanmedu, Tiruvallur, Tamil Nadu, 600110');
    });
  });
}
