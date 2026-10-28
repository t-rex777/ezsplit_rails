import 'dart:async';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:ezsplit_mobile/app.dart';
import 'package:ezsplit_mobile/data/api_client.dart';
import 'package:ezsplit_mobile/data/auth_repository.dart';
import 'package:ezsplit_mobile/data/models.dart';
import 'package:ezsplit_mobile/router.dart';
import 'package:ezsplit_mobile/state/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

const testUser = User(
  id: 1,
  firstName: 'Neha',
  lastName: 'Kapoor',
  email: 'neha@gmail.com',
);

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.current, this.currentGate});

  User? current;

  /// When set, currentUser() waits on it, so tests can hold the session in loading.
  Completer<void>? currentGate;

  Object? currentError;
  Object? loginError;
  Object? resetError;
  final List<Map<String, Object?>> invites = [];
  final List<String> resets = [];

  @override
  Future<User?> currentUser() async {
    await currentGate?.future;
    if (currentError != null) throw currentError!;
    return current;
  }

  @override
  Future<User> login(String email, String password) async {
    if (loginError != null) throw loginError!;
    return current = testUser;
  }

  int logouts = 0;
  Completer<void>? logoutGate;

  @override
  Future<void> logout() async {
    logouts++;
    await logoutGate?.future;
  }

  @override
  Future<User> acceptInvite({
    required String token,
    required String email,
    required String firstName,
    required String lastName,
    required String phone,
    required DateTime dob,
    required String password,
  }) async {
    invites.add({
      'token': token,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'phone': phone,
      'dob': dob,
      'password': password,
    });
    return current = testUser;
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    if (resetError != null) throw resetError!;
    resets.add(email);
  }
}

ApiClient dummyClient() => ApiClient(Dio(BaseOptions(baseUrl: 'http://test')));

List<Override> overridesFor(FakeAuthRepository repo, {ApiClient? client}) => [
  apiClientProvider.overrideWithValue(client ?? dummyClient()),
  cookieJarProvider.overrideWithValue(CookieJar()),
  authRepositoryProvider.overrideWithValue(repo),
];

Future<ProviderContainer> pumpApp(
  WidgetTester tester,
  FakeAuthRepository repo, {
  ApiClient? client,
  Stream<Uri>? links,
  List<Override> extraOverrides = const [],
  // The splash loader never settles; tests that stop on it pass false.
  bool settle = true,
  // Most tests skip the splash's minimum time; splash tests set it.
  Duration splashMin = Duration.zero,
}) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overridesFor(repo, client: client),
        splashMinDurationProvider.overrideWithValue(splashMin),
        ...extraOverrides,
      ],
      child: EzsplitApp(listenForLinks: false, linkStream: links),
    ),
  );
  settle ? await tester.pumpAndSettle() : await tester.pump();
  return ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
}

GoRouter routerOf(ProviderContainer c) => c.read(routerProvider);

String locationOf(ProviderContainer c) =>
    routerOf(c).routerDelegate.currentConfiguration.uri.toString();
