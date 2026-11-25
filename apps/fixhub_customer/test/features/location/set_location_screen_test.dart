import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fixhub_customer/features/location/domain/repositories/location_repository.dart';
import 'package:fixhub_customer/features/location/presentation/providers/location_provider.dart';
import 'package:fixhub_customer/features/location/presentation/screens/set_location_screen.dart';

class MockLocationRepository extends Mock implements LocationRepository {}

class FakeLocationNotifier extends StateNotifier<LocationState> implements LocationNotifier {
  FakeLocationNotifier(super.state);

  String? validatedPincode;

  @override
  Future<void> validateManualPincode(String pincode) async {
    validatedPincode = pincode;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late MockLocationRepository mockRepository;
  late FakeLocationNotifier fakeLocationNotifier;

  setUp(() {
    mockRepository = MockLocationRepository();
    fakeLocationNotifier = FakeLocationNotifier(const LocationState());
  });

  Widget buildTestWidget() {
    return ProviderScope(
      overrides: [
        locationRepositoryProvider.overrideWithValue(mockRepository),
        locationProvider.overrideWith((ref) => fakeLocationNotifier),
      ],
      child: const MaterialApp(
        home: SetLocationScreen(),
      ),
    );
  }

  testWidgets('renders Choose your location button and triggers validation', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Choose your location'), findsOneWidget);
    expect(find.text('Enter 6-digit Pincode'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '621103');
    await tester.pump();

    await tester.tap(find.text('Choose your location'));
    await tester.pump();

    expect(fakeLocationNotifier.validatedPincode, '621103');
  });
}

