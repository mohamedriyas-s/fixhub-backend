import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:geolocator/geolocator.dart';
import 'package:fixhub_customer/core/storage/local_storage.dart';
import 'package:fixhub_customer/features/location/domain/repositories/location_repository.dart';
import 'package:fixhub_customer/features/location/data/models/service_area_validation_model.dart';
import 'package:fixhub_customer/features/location/presentation/providers/location_provider.dart';

class MockLocationRepository extends Mock implements LocationRepository {}
class MockLocalStorage extends Mock implements LocalStorage {}

void main() {
  late MockLocationRepository mockRepository;
  late MockLocalStorage mockLocalStorage;

  setUp(() {
    mockRepository = MockLocationRepository();
    mockLocalStorage = MockLocalStorage();

    when(() => mockRepository.checkPermission()).thenAnswer((_) async => true);
    when(() => mockLocalStorage.getSavedLocationStatus()).thenAnswer((_) async => null);
    when(() => mockLocalStorage.getSavedPincode()).thenAnswer((_) async => null);
    when(() => mockLocalStorage.getSavedCity()).thenAnswer((_) async => null);
    when(() => mockLocalStorage.saveLocation(
          pincode: any(named: 'pincode'),
          status: any(named: 'status'),
          city: any(named: 'city'),
        )).thenAnswer((_) async {});
  });

  group('LocationNotifier Tests', () {
    test('State copyWith clears errorMessage when clearErrorMessage is true', () {
      const state = LocationState(
        status: LocationStatus.error,
        errorMessage: 'Location permission denied.',
      );

      final updated = state.copyWith(
        status: LocationStatus.checking,
        clearErrorMessage: true,
      );

      expect(updated.status, LocationStatus.checking);
      expect(updated.errorMessage, isNull);
    });

    test('validateManualPincode resolves address and sets invalid coverage cleanly for unserviced 621103', () async {
      when(() => mockRepository.getAddressFromPincode('621103')).thenAnswer(
        (_) async => {
          'pincode': '621103',
          'city': 'Veppanthattai, Perambalur',
          'state': 'Tamil Nadu',
        },
      );

      when(() => mockRepository.validateServiceArea('621103', lat: any(named: 'lat'), lng: any(named: 'lng'))).thenAnswer(
        (_) async => const ServiceAreaValidationModel(
          pincode: '621103',
          isCovered: false,
          isServiceable: false,
          hasTechnicianCoverage: false,
          activeTechnicianCount: 0,
          reason: 'PINCODE_NOT_COVERED',
        ),
      );

      final notifier = LocationNotifier(mockRepository, mockLocalStorage);
      await Future<void>.delayed(Duration.zero);

      await notifier.validateManualPincode('621103');

      expect(notifier.state.status, LocationStatus.invalid);
      expect(notifier.state.currentPincode, '621103');
      expect(notifier.state.currentCity, 'Veppanthattai, Perambalur');
      expect(notifier.state.errorMessage, isNull);

      // Invalid locations must never be saved to persistent storage
      verifyNever(() => mockLocalStorage.saveLocation(
            pincode: any(named: 'pincode'),
            status: any(named: 'status'),
            city: any(named: 'city'),
          ));
    });

    test('clearError resets status from error to initial and wipes errorMessage', () {
      final notifier = LocationNotifier(mockRepository, mockLocalStorage);
      // Simulate error
      notifier.state = notifier.state.copyWith(
        status: LocationStatus.error,
        errorMessage: 'Network issue. Please check your internet connection.',
      );

      notifier.clearError();

      expect(notifier.state.status, LocationStatus.initial);
      expect(notifier.state.errorMessage, isNull);
    });

    test('validates Kolathur 600099 with name, district, state, pincode format', () async {
      when(() => mockRepository.getAddressFromPincode('600099')).thenAnswer(
        (_) async => {
          'name': 'Kolathur',
          'district': 'Tiruvallur',
          'state': 'Tamil Nadu',
          'pincode': '600099',
          'city': 'Kolathur, Tiruvallur, Tamil Nadu, 600099',
        },
      );

      when(() => mockRepository.validateServiceArea('600099', lat: any(named: 'lat'), lng: any(named: 'lng'))).thenAnswer(
        (_) async => const ServiceAreaValidationModel(
          pincode: '600099',
          isCovered: true,
          isServiceable: true,
          hasTechnicianCoverage: true,
          activeTechnicianCount: 2,
          reason: 'COVERED',
        ),
      );

      final notifier = LocationNotifier(mockRepository, mockLocalStorage);
      await Future<void>.delayed(Duration.zero);

      await notifier.validateManualPincode('600099');

      expect(notifier.state.status, LocationStatus.valid);
      expect(notifier.state.currentPincode, '600099');
      expect(notifier.state.currentCity, 'Kolathur, Tiruvallur, Tamil Nadu, 600099');
      expect(notifier.state.errorMessage, isNull);

      verify(() => mockLocalStorage.saveLocation(
            pincode: '600099',
            status: 'valid',
            city: 'Kolathur, Tiruvallur, Tamil Nadu, 600099',
          )).called(1);
    });

    test('validates Ponniammanmedu 600110 with name, district, state, pincode format', () async {
      when(() => mockRepository.getAddressFromPincode('600110')).thenAnswer(
        (_) async => {
          'name': 'Ponniammanmedu',
          'district': 'Tiruvallur',
          'state': 'Tamil Nadu',
          'pincode': '600110',
          'city': 'Ponniammanmedu, Tiruvallur, Tamil Nadu, 600110',
        },
      );

      when(() => mockRepository.validateServiceArea('600110', lat: any(named: 'lat'), lng: any(named: 'lng'))).thenAnswer(
        (_) async => const ServiceAreaValidationModel(
          pincode: '600110',
          isCovered: false,
          isServiceable: false,
          hasTechnicianCoverage: false,
          activeTechnicianCount: 0,
          reason: 'PINCODE_NOT_COVERED',
        ),
      );

      final notifier = LocationNotifier(mockRepository, mockLocalStorage);
      await Future<void>.delayed(Duration.zero);

      await notifier.validateManualPincode('600110');

      expect(notifier.state.status, LocationStatus.invalid);
      expect(notifier.state.currentPincode, '600110');
      expect(notifier.state.currentCity, 'Ponniammanmedu, Tiruvallur, Tamil Nadu, 600110');
      expect(notifier.state.errorMessage, isNull);

      // Invalid locations must never be saved to persistent storage
      verifyNever(() => mockLocalStorage.saveLocation(
            pincode: any(named: 'pincode'),
            status: any(named: 'status'),
            city: any(named: 'city'),
          ));
    });

    test('revertToLastValidLocation restores previous valid location', () async {
      when(() => mockLocalStorage.getSavedLocationStatus()).thenAnswer((_) async => 'valid');
      when(() => mockLocalStorage.getSavedPincode()).thenAnswer((_) async => '600001');
      when(() => mockLocalStorage.getSavedCity()).thenAnswer((_) async => 'Chennai');

      final notifier = LocationNotifier(mockRepository, mockLocalStorage);
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.status, LocationStatus.valid);
      expect(notifier.state.currentPincode, '600001');

      // Now simulate checking an unserviced pincode
      when(() => mockRepository.getAddressFromPincode('621103')).thenAnswer(
        (_) async => {
          'pincode': '621103',
          'city': 'Musiri',
          'state': 'Tamil Nadu',
        },
      );
      when(() => mockRepository.validateServiceArea('621103', lat: any(named: 'lat'), lng: any(named: 'lng'))).thenAnswer(
        (_) async => const ServiceAreaValidationModel(
          pincode: '621103',
          isCovered: false,
          isServiceable: false,
          hasTechnicianCoverage: false,
          activeTechnicianCount: 0,
          reason: 'PINCODE_NOT_COVERED',
        ),
      );

      await notifier.validateManualPincode('621103');
      expect(notifier.state.status, LocationStatus.invalid);
      expect(notifier.state.currentPincode, '621103');

      // Now revert
      notifier.revertToLastValidLocation();
      expect(notifier.state.status, LocationStatus.valid);
      expect(notifier.state.currentPincode, '600001');
      expect(notifier.state.currentCity, 'Chennai');
    });
  });
}

