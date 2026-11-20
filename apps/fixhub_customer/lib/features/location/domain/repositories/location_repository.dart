import 'package:geolocator/geolocator.dart';
import '../../data/models/service_area_validation_model.dart';

abstract class LocationRepository {
  Future<bool> checkPermission();
  Future<bool> requestPermission();
  Future<Position> getCurrentLocation();
  Future<Map<String, String>?> getAddressFromPosition(Position position);
  Future<Map<String, String>?> getAddressFromPincode(String pincode);
  Future<ServiceAreaValidationModel> validateServiceArea(String pincode, {double? lat, double? lng});
  Future<void> requestCoverage(String pincode, String name, String phone, String email);
}
