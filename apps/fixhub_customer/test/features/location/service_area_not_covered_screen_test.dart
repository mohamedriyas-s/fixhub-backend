import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fixhub_customer/features/auth/data/models/user_model.dart';
import 'package:fixhub_customer/features/auth/presentation/providers/auth_provider.dart';
import 'package:fixhub_customer/features/location/domain/repositories/location_repository.dart';
import 'package:fixhub_customer/features/location/presentation/providers/location_provider.dart';
import 'package:fixhub_customer/features/location/presentation/screens/service_area_not_covered_screen.dart';

class MockLocationRepository extends Mock implements LocationRepository {}

class FakeAuthNotifier extends StateNotifier<AuthState> implements AuthNotifier {
  FakeAuthNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeLocationNotifier extends StateNotifier<LocationState> implements LocationNotifier {
  FakeLocationNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late MockLocationRepository mockRepository;

  const testUser = UserModel(
    id: 'user-123',
    phone: '+919876543210',
    name: 'Suresh Kumar',
    email: 'suresh@example.com',
    role: 'customer',
  );

  setUp(() {
    mockRepository = MockLocationRepository();
    when(
      () => mockRepository.requestCoverage(
        any(),
        any(),
        any(),
        any(),
      ),
    ).thenAnswer((_) async {});
  });

  Widget buildTestWidget({
    AuthState authState = const AuthState(
      status: AuthStatus.authenticated,
      user: testUser,
    ),
    LocationState locationState = const LocationState(
      status: LocationStatus.invalid,
      currentPincode: '600110',
      currentCity: 'Ponniammanmedu, Tiruvallur, Tamil Nadu, 600110',
      isRestoring: false,
    ),
  }) {
    return ProviderScope(
      overrides: [
        locationRepositoryProvider.overrideWithValue(mockRepository),
        authProvider.overrideWith((ref) => FakeAuthNotifier(authState)),
        locationProvider.overrideWith((ref) => FakeLocationNotifier(locationState)),
      ],
      child: const MaterialApp(
        home: ServiceAreaNotCoveredScreen(),
      ),
    );
  }

  testWidgets('renders "We\'re not here yet" screen with unserviced pincode and notify me button', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.text("We're not here yet"), findsOneWidget);
    expect(find.textContaining('600110'), findsWidgets);
    expect(find.text('Notify me when live'), findsOneWidget);
    expect(find.text('Change Location'), findsOneWidget);
  });

  testWidgets('clicking "Notify me when live" submits request seamlessly (Option A) and stays on "We\'ll notify you!" screen', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Click "Notify me when live"
    final notifyButton = find.text('Notify me when live');
    expect(notifyButton, findsOneWidget);
    await tester.tap(notifyButton);
    await tester.pump();
    await tester.pumpAndSettle();

    // Verify repository was called with authenticated user's details
    verify(
      () => mockRepository.requestCoverage(
        '600110',
        'Suresh Kumar',
        '+919876543210',
        'suresh@example.com',
      ),
    ).called(1);

    // Verify UI transitioned to "We'll notify you!" state in-page
    expect(find.text("We'll notify you!"), findsOneWidget);
    expect(find.textContaining('+919876543210'), findsOneWidget);
    expect(find.text('Waitlist confirmed'), findsOneWidget);

    // Verify "Change Location" button is present and screen remains intact
    expect(find.text('Change Location'), findsOneWidget);
  });
}
