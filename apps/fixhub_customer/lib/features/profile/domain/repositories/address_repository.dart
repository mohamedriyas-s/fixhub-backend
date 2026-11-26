import '../../../booking/data/models/address_model.dart';

abstract class AddressRepository {
  Future<List<AddressModel>> getAddresses();
  Future<AddressModel> addAddress(AddressModel address);
  Future<AddressModel> updateAddress(String id, AddressModel address);
  Future<AddressModel> setDefaultAddress(String id);
  Future<void> deleteAddress(String id);
}
