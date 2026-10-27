import 'package:cookie_jar/cookie_jar.dart';

import 'api_client.dart';
import 'api_error.dart';
import 'models.dart';

class AuthRepository {
  AuthRepository(this._api, this._jar);

  final ApiClient _api;
  final CookieJar _jar;

  Future<User> login(String email, String password) async {
    final json = await _api.post(
      '/session',
      body: {'email_address': email, 'password': password},
    );
    final user =
        (json['data'] as Map<String, dynamic>)['user'] as Map<String, dynamic>;
    return User.fromJson(user['data'] as Map<String, dynamic>);
  }

  Future<void> logout() async {
    try {
      await _api.delete('/session');
    } finally {
      await _jar.deleteAll();
    }
  }

  Future<User?> currentUser() async {
    try {
      final json = await _api.get('/');
      return User.fromJson(json['data'] as Map<String, dynamic>);
    } on ApiError catch (e) {
      if (e.isUnauthorized) return null;
      rethrow;
    }
  }

  Future<User> acceptInvite({
    required String token,
    required String email,
    required String firstName,
    required String lastName,
    required String phone,
    required DateTime dob,
    required String password,
  }) async {
    final json = await _api.post(
      '/user_registers',
      body: {
        'token': token,
        'user': {
          'email_address': email,
          'password': password,
          'password_confirmation': password,
          'first_name': firstName,
          'last_name': lastName,
          'phone': phone,
          'date_of_birth': _isoDate(dob),
        },
      },
    );
    return User.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<void> requestPasswordReset(String email) async {
    await _api.post('/passwords', body: {'email_address': email});
  }

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
