import '../../../core/network/http_client.dart';
import '../../../core/storage/app_storage.dart';
import '../models/user_model.dart';

class AuthService {
  final ApiClient _client;
  AuthService(this._client);

  Future<UserModel> login(String email, String password) async {
    final data = await _client.post(
      'auth/login',
      {'email': email, 'password': password},
      isV8: false,
    );
    final token = data['access_token'] as String;
    final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
    await AppStorage.setToken(token);
    await AppStorage.setUser(user.toJson());
    return user;
  }

  Future<void> logout() async {
    await AppStorage.clearToken();
  }

  Future<bool> isLoggedIn() async {
    final token = await AppStorage.getToken();
    return token != null && token.isNotEmpty;
  }

  Future<UserModel?> getStoredUser() async {
    final json = await AppStorage.getUser();
    if (json == null) return null;
    return UserModel.fromJson(json);
  }
}
