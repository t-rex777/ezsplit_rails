import 'dart:convert';
import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:ezsplit_mobile/data/api_client.dart';
import 'package:ezsplit_mobile/data/api_error.dart';
import 'package:ezsplit_mobile/data/auth_repository.dart';
import 'package:ezsplit_mobile/data/models.dart';
import 'package:ezsplit_mobile/state/session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

Map<String, dynamic> fixture(String name) =>
    jsonDecode(File('test/fixtures/$name').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late CookieJar jar;
  late AuthRepository repo;
  late int unauthorizedCalls;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://test'));
    adapter = DioAdapter(dio: dio);
    jar = CookieJar();
    unauthorizedCalls = 0;
    repo = AuthRepository(
      ApiClient(dio, cookieJar: jar, onUnauthorized: () => unauthorizedCalls++),
      jar,
    );
  });

  test('User.fromJson reads a JSON:API resource', () {
    final u = User.fromJson(
      fixture('me_root.json')['data'] as Map<String, dynamic>,
    );
    expect(u.id, 2);
    expect(u.firstName, 'Milisha');
    expect(u.lastName, 'Saran');
    expect(u.email, 'milisha.demo@example.com');
    expect(u.phone, '9876543210');
    expect(u.dob, DateTime(1996, 3, 12));
    expect(u.initials, 'MS');
  });

  test('login posts credentials and returns the nested user', () async {
    adapter.onPost(
      '/session',
      (s) => s.reply(200, fixture('login.json')),
      data: {'email_address': 'a@b.com', 'password': 'secret'},
    );
    final u = await repo.login('a@b.com', 'secret');
    expect(u.id, 2);
  });

  test(
    'failed login throws ApiError and does not fire onUnauthorized',
    () async {
      adapter.onPost(
        '/session',
        (s) => s.reply(401, {
          'status': 'error',
          'errors': ['Invalid credentials'],
          'message': 'Invalid email address or password',
        }),
        data: Matchers.any,
      );
      await expectLater(
        repo.login('a@b.com', 'bad'),
        throwsA(
          isA<ApiError>().having(
            (e) => e.message,
            'message',
            'Invalid credentials',
          ),
        ),
      );
      expect(unauthorizedCalls, 0);
    },
  );

  test('currentUser returns the user from GET /', () async {
    adapter.onGet('/', (s) => s.reply(200, fixture('me_root.json')));
    expect((await repo.currentUser())!.firstName, 'Milisha');
  });

  test('currentUser returns null on 401', () async {
    adapter.onGet(
      '/',
      (s) => s.reply(401, {
        'errors': ['x'],
      }),
    );
    expect(await repo.currentUser(), isNull);
  });

  test('currentUser returns null on a 302 to /session/new', () async {
    adapter.onGet(
      '/',
      (s) => s.reply(
        302,
        '',
        headers: {
          'location': ['http://test/session/new'],
        },
      ),
    );
    expect(await repo.currentUser(), isNull);
  });

  test('logout calls DELETE /session and clears the cookie jar', () async {
    await jar.saveFromResponse(Uri.parse('http://test/'), [
      Cookie('session_id', 'abc'),
    ]);
    adapter.onDelete(
      '/session',
      (s) => s.reply(200, {'status': 'success', 'message': 'Signed out'}),
    );
    await repo.logout();
    expect(await jar.loadForRequest(Uri.parse('http://test/')), isEmpty);
  });

  test('acceptInvite posts the token and nested user body', () async {
    adapter.onPost(
      '/user_registers',
      (s) => s.reply(200, fixture('me_root.json')),
      data: {
        'token': 'tok',
        'user': {
          'email_address': 'a@b.com',
          'password': 'pw123456',
          'password_confirmation': 'pw123456',
          'first_name': 'A',
          'last_name': 'B',
          'phone': '9876543210',
          'date_of_birth': '1996-03-05',
        },
      },
    );
    final u = await repo.acceptInvite(
      token: 'tok',
      email: 'a@b.com',
      firstName: 'A',
      lastName: 'B',
      phone: '9876543210',
      dob: DateTime(1996, 3, 5),
      password: 'pw123456',
    );
    expect(u.id, 2);
  });

  test('requestPasswordReset posts the email', () async {
    adapter.onPost(
      '/passwords',
      (s) => s.reply(200, {'status': 'success'}),
      data: {'email_address': 'a@b.com'},
    );
    await repo.requestPasswordReset('a@b.com');
  });

  group('sessionProvider', () {
    ProviderContainer make() {
      final c = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(ApiClient(dio, cookieJar: jar)),
          cookieJarProvider.overrideWithValue(jar),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('build loads the current user', () async {
      adapter.onGet('/', (s) => s.reply(200, fixture('me_root.json')));
      final c = make();
      expect((await c.read(sessionProvider.future))!.id, 2);
    });

    test(
      'a 401 on any later call expires the session with a message',
      () async {
        adapter.onGet('/', (s) => s.reply(200, fixture('me_root.json')));
        adapter.onGet(
          '/groups',
          (s) => s.reply(401, {
            'errors': ['x'],
          }),
        );
        final c = make();
        await c.read(sessionProvider.future);
        await expectLater(
          c.read(apiClientProvider).get('/groups'),
          throwsA(isA<ApiError>()),
        );
        expect(c.read(sessionProvider).value, isNull);
        expect(
          c.read(sessionProvider.notifier).expiredMessage,
          'Your session expired. Log in again.',
        );
      },
    );

    test('signed out at start has no expired message', () async {
      adapter.onGet(
        '/',
        (s) => s.reply(401, {
          'errors': ['x'],
        }),
      );
      final c = make();
      expect(await c.read(sessionProvider.future), isNull);
      expect(c.read(sessionProvider.notifier).expiredMessage, isNull);
    });

    test('failed login leaves the session and message untouched', () async {
      adapter.onGet(
        '/',
        (s) => s.reply(401, {
          'errors': ['x'],
        }),
      );
      adapter.onPost(
        '/session',
        (s) => s.reply(401, {
          'errors': ['Invalid credentials'],
        }),
        data: Matchers.any,
      );
      final c = make();
      await c.read(sessionProvider.future);
      await expectLater(
        c.read(sessionProvider.notifier).login('a@b.com', 'bad'),
        throwsA(isA<ApiError>()),
      );
      expect(c.read(sessionProvider).value, isNull);
      expect(c.read(sessionProvider.notifier).expiredMessage, isNull);
    });

    test('login sets the user and logout clears it', () async {
      adapter.onGet(
        '/',
        (s) => s.reply(401, {
          'errors': ['x'],
        }),
      );
      adapter.onPost(
        '/session',
        (s) => s.reply(200, fixture('login.json')),
        data: Matchers.any,
      );
      adapter.onDelete('/session', (s) => s.reply(200, {'status': 'success'}));
      final c = make();
      await c.read(sessionProvider.future);
      await c.read(sessionProvider.notifier).login('a@b.com', 'pw');
      expect(c.read(sessionProvider).value!.id, 2);
      await c.read(sessionProvider.notifier).logout();
      expect(c.read(sessionProvider).value, isNull);
    });
  });
}
