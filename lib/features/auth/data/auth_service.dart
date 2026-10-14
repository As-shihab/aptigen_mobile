import 'package:flutter/foundation.dart';
import '../../../core/network/http_client.dart';
import '../../../core/storage/app_storage.dart';
import '../models/user_model.dart';

/// Who's signed in, app-wide. Cart and wishlist stores listen to this to
/// switch between guest (on-device) and account (server) mode.
class Session {
  const Session._();

  static final user = ValueNotifier<UserModel?>(null);

  static bool get isSignedIn => user.value != null;

  static Future<void> restore() async {
    final token = await AppStorage.getToken();
    final json = await AppStorage.getUser();
    if (token == null || token.isEmpty || json == null) return;
    try {
      user.value = UserModel.fromJson(json);
    } catch (_) {
      await AppStorage.clearToken();
    }
  }

  /// A 401 from any signed-in call means the token is dead.
  static Future<void> expire() async {
    await AppStorage.clearToken();
    user.value = null;
  }
}

class AuthService {
  final ApiClient _client;
  AuthService(this._client);

  Future<UserModel> login(String email, String password) async {
    final data = await _client.post(
      'auth/login',
      {'email': email, 'password': password},
    );
    final token = data['access_token'] as String;
    final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
    await AppStorage.setToken(token);
    await AppStorage.setUser(user.toJson());
    Session.user.value = user;
    return user;
  }

  /// Creates an account (POST /api/auth/signup) with an email or a phone
  /// number — same body as the web signup. The user then signs in.
  Future<void> signup({required String name, required String password, String? email, String? phone}) async {
    await _client.post('auth/signup', {
      'name': name.trim(),
      'password': password,
      if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
      if ((email == null || email.trim().isEmpty) && phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
    });
  }

  Future<void> logout() async {
    await AppStorage.clearToken();
    Session.user.value = null;
  }
}
