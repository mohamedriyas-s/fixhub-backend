import '../../../booking/data/models/address_model.dart';
import '../../domain/repositories/address_repository.dart';
import '../datasources/address_remote_datasource.dart';

class AddressRepositoryImpl implements AddressRepository {
  final AddressRemoteDataSource _remoteDataSource;

  AddressRepositoryImpl(this._remoteDataSource);

  @override
  Future<List<AddressModel>> getAddresses() async {
    final data = await _remoteDataSource.getAddresses();
    return (data as List).map((json) => AddressModel.fromJson(Map<String, dynamic>.from(json))).toList();
  }

  Map<String, dynamic> _toPayload(AddressModel address) {
    return {
      'label': address.label,
      'line1': address.line1,
      if (address.line2 != null && address.line2!.isNotEmpty) 'line2': address.line2,
      if (address.landmark != null && address.landmark!.isNotEmpty) 'landmark': address.landmark,
      'city': address.city,
      'state': address.state,
      'pincode': address.pincode,
      'isDefault': address.isDefault,
      if (address.latitude != null) 'latitude': address.latitude,
      if (address.longitude != null) 'longitude': address.longitude,
    };
  }

  @override
  Future<AddressModel> addAddress(AddressModel address) async {
    final data = await _remoteDataSource.addAddress(_toPayload(address));
    return AddressModel.fromJson(Map<String, dynamic>.from(data));
  }

  @override
  Future<AddressModel> updateAddress(String id, AddressModel address) async {
    final data = await _remoteDataSource.updateAddress(id, _toPayload(address));
    return AddressModel.fromJson(Map<String, dynamic>.from(data));
  }

  @override
  Future<AddressModel> setDefaultAddress(String id) async {
    final data = await _remoteDataSource.setDefaultAddress(id);
    return AddressModel.fromJson(Map<String, dynamic>.from(data));
  }

  @override
  Future<void> deleteAddress(String id) async {
    await _remoteDataSource.deleteAddress(id);
  }
}
