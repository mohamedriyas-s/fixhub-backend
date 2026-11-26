import '../../data/models/auth_response_model.dart';
import '../../data/models/user_model.dart';

/// Abstract auth repository — domain layer contract.
abstract class AuthRepository {
  Future<String?> sendOtp(String email);
  Future<AuthResponseModel> verifyOtp({
    required String email,
    required String otp,
  });
  Future<UserModel> getProfile();
  Future<void> logout();
  Future<bool> isLoggedIn();
  Future<UserModel?> getCachedUser();
}
