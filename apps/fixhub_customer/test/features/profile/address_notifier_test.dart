import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fixhub_customer/features/booking/data/models/address_model.dart';
import 'package:fixhub_customer/features/profile/domain/repositories/address_repository.dart';
import 'package:fixhub_customer/features/profile/presentation/providers/address_provider.dart';

class _MockAddressRepository extends Mock implements AddressRepository {}

void main() {
  late _MockAddressRepository repository;

  const addr1 = AddressModel(
    id: 'addr-1',
    label: 'Home',
    line1: '101 Towers',
    line2: 'MG Road',
    city: 'Chennai',
    state: 'Tamil Nadu',
    pincode: '600099',
    isDefault: true,
  );

  const addr2 = AddressModel(
    id: 'addr-2',
    label: 'Work',
    line1: '202 Tech Park',
    line2: 'OMR',
    city: 'Chennai',
    state: 'Tamil Nadu',
    pincode: '600099',
    isDefault: false,
  );

  setUp(() {
    repository = _MockAddressRepository();
  });

  test('setDefaultAddress sets target as default and clears previous default', () async {
    when(() => repository.getAddresses()).thenAnswer((_) async => [addr1, addr2]);
    when(() => repository.setDefaultAddress('addr-2'))
        .thenAnswer((_) async => addr2.copyWith(isDefault: true));

    final notifier = AddressNotifier(repository);
    await notifier.fetchAddresses();

    await notifier.setDefaultAddress('addr-2');

    final list = notifier.state.value!;
    expect(list.firstWhere((a) => a.id == 'addr-1').isDefault, isFalse);
    expect(list.firstWhere((a) => a.id == 'addr-2').isDefault, isTrue);
  });
}
