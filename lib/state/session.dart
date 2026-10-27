import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api_client.dart';
import '../data/auth_repository.dart';
import '../data/models.dart';

const String sessionExpiredMessage = 'Your session expired. Log in again.';

/// Overridden at startup with the client from createApiClient.
final apiClientProvider = Provider<ApiClient>(
  (ref) => throw UnimplementedError('apiClientProvider must be overridden'),
);

/// Overridden at startup with the jar behind the client.
final cookieJarProvider = Provider<CookieJar>(
  (ref) => throw UnimplementedError('cookieJarProvider must be overridden'),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(cookieJarProvider),
  ),
);

class SessionNotifier extends AsyncNotifier<User?> {
  /// Set when a 401 ends the session; the login screen shows it once.
  String? expiredMessage;

  @override
  Future<User?> build() {
    ref.read(apiClientProvider).onUnauthorized = expire;
    return ref.read(authRepositoryProvider).currentUser();
  }

  void expire() {
    // Nothing to expire while loading or already signed out.
    if (state.value == null) return;
    expiredMessage = sessionExpiredMessage;
    state = const AsyncData(null);
  }

  Future<void> login(String email, String password) async {
    final user = await ref.read(authRepositoryProvider).login(email, password);
    expiredMessage = null;
    state = AsyncData(user);
  }

  /// The server signs the new user in and sets the cookie, so this ends signed in.
  Future<void> acceptInvite({
    required String token,
    required String email,
    required String firstName,
    required String lastName,
    required String phone,
    required DateTime dob,
    required String password,
  }) async {
    final user = await ref
        .read(authRepositoryProvider)
        .acceptInvite(
          token: token,
          email: email,
          firstName: firstName,
          lastName: lastName,
          phone: phone,
          dob: dob,
          password: password,
        );
    expiredMessage = null;
    state = AsyncData(user);
  }

  Future<void> logout() async {
    try {
      await ref.read(authRepositoryProvider).logout();
    } finally {
      expiredMessage = null;
      state = const AsyncData(null);
    }
  }
}

final sessionProvider = AsyncNotifierProvider<SessionNotifier, User?>(
  SessionNotifier.new,
);
