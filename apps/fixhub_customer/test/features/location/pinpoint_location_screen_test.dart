import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fixhub_customer/features/booking/data/models/address_model.dart';
import 'package:fixhub_customer/features/location/presentation/screens/pinpoint_location_screen.dart';

void main() {
  const sampleAddress = AddressModel(
    id: 'addr-1',
    label: 'Home',
    line1: '123 Kolathur Main Rd',
    city: 'Chennai',
    state: 'Tamil Nadu',
    pincode: '600099',
    latitude: 13.1185,
    longitude: 80.2085,
  );

  testWidgets('PinpointLocationScreen renders map container and UI controls with initial address', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: PinpointLocationScreen(
            initialAddress: sampleAddress,
            bookingId: 'booking-1',
          ),
        ),
      ),
    );

    await tester.pump();

    // Verify search bar exists
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Search street, area, or pincode...'), findsOneWidget);

    // Verify center pin indicator
    expect(find.text('Exact Doorstep'), findsOneWidget);
    expect(find.byIcon(Icons.location_on_rounded), findsWidgets);

    // Verify bottom confirmation button
    expect(find.text('Confirm Doorstep Location'), findsOneWidget);
  });
}

