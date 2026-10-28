import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:ezsplit_mobile/data/api_client.dart';
import 'package:ezsplit_mobile/data/api_error.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late ApiClient client;
  late int unauthorizedCalls;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://test'));
    adapter = DioAdapter(dio: dio);
    unauthorizedCalls = 0;
    client = ApiClient(dio, onUnauthorized: () => unauthorizedCalls++);
  });

  test('sends Accept and Content-Type headers', () async {
    adapter.onGet(
      '/groups',
      (s) => s.reply(200, {'ok': true}),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    );
    expect(await client.get('/groups'), {'ok': true});
  });

  test('422 surfaces the first entry of errors', () async {
    adapter.onPost(
      '/expenses',
      (s) => s.reply(422, {
        'errors': ['Amount is required', 'Other'],
        'message': 'nope',
      }),
      data: Matchers.any,
    );
    await expectLater(
      client.post('/expenses', body: {}),
      throwsA(
        isA<ApiError>()
            .having((e) => e.message, 'message', 'Amount is required')
            .having((e) => e.status, 'status', 422),
      ),
    );
    expect(unauthorizedCalls, 0);
  });

  test('falls back to message when errors is absent', () async {
    adapter.onGet('/x', (s) => s.reply(500, {'message': 'Boom'}));
    await expectLater(
      client.get('/x'),
      throwsA(isA<ApiError>().having((e) => e.message, 'message', 'Boom')),
    );
  });

  test('401 is unauthorized and fires onUnauthorized', () async {
    adapter.onGet(
      '/groups',
      (s) => s.reply(401, {
        'errors': ['No'],
      }),
    );
    await expectLater(
      client.get('/groups'),
      throwsA(
        isA<ApiError>().having((e) => e.isUnauthorized, 'isUnauthorized', true),
      ),
    );
    expect(unauthorizedCalls, 1);
  });

  test('302 to /session/new is unauthorized with status 401', () async {
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
    await expectLater(
      client.get('/'),
      throwsA(
        isA<ApiError>()
            .having((e) => e.status, 'status', 401)
            .having((e) => e.isUnauthorized, 'isUnauthorized', true),
      ),
    );
    expect(unauthorizedCalls, 1);
  });

  test('302 is handled the same when dio does not throw on 3xx', () async {
    dio = Dio(BaseOptions(baseUrl: 'http://test', validateStatus: (_) => true));
    adapter = DioAdapter(dio: dio);
    client = ApiClient(dio, onUnauthorized: () => unauthorizedCalls++);
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
    await expectLater(
      client.get('/'),
      throwsA(isA<ApiError>().having((e) => e.status, 'status', 401)),
    );
  });

  test('failed login 401 does not fire onUnauthorized', () async {
    adapter.onPost(
      '/session',
      (s) => s.reply(401, {
        'errors': ['Invalid credentials'],
        'message': 'Invalid email address or password',
      }),
      data: Matchers.any,
    );
    await expectLater(
      client.post('/session', body: {'email_address': 'a', 'password': 'b'}),
      throwsA(
        isA<ApiError>()
            .having((e) => e.status, 'status', 401)
            .having((e) => e.message, 'message', 'Invalid credentials'),
      ),
    );
    expect(unauthorizedCalls, 0);
  });

  test('no response gives the connection message and does not fire', () async {
    adapter.onGet(
      '/x',
      (s) => s.throws(
        500,
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.connectionError,
        ),
      ),
    );
    await expectLater(
      client.get('/x'),
      throwsA(
        isA<ApiError>()
            .having((e) => e.status, 'status', null)
            .having(
              (e) => e.message,
              'message',
              "Couldn't reach ezsplit. Check your connection.",
            ),
      ),
    );
    expect(unauthorizedCalls, 0);
  });

  test('keeps a cookie jar reference for logout', () {
    final jar = CookieJar();
    expect(ApiClient(dio, cookieJar: jar).cookieJar, same(jar));
  });

  test(
    'onOffline fires when no response arrives, onOnline on any response',
    () async {
      var offline = 0;
      var online = 0;
      client.onOffline = () => offline++;
      client.onOnline = () => online++;
      adapter.onGet(
        '/down',
        (s) => s.throws(
          0,
          DioException(
            requestOptions: RequestOptions(path: '/down'),
            type: DioExceptionType.connectionError,
          ),
        ),
      );
      adapter.onGet('/bad', (s) => s.reply(422, {'message': 'Nope'}));
      await expectLater(client.get('/down'), throwsA(isA<ApiError>()));
      expect((offline, online), (1, 0));
      await expectLater(client.get('/bad'), throwsA(isA<ApiError>()));
      expect((offline, online), (1, 1));
    },
  );

  group('timeouts', () {
    test('the real client sets connect, send and receive timeouts', () {
      final o = apiBaseOptions('http://test');
      expect(o.connectTimeout, const Duration(seconds: 15));
      expect(o.sendTimeout, const Duration(seconds: 30));
      expect(o.receiveTimeout, const Duration(seconds: 30));
    });

    for (final type in [
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
    ]) {
      test('$type gives the connection message and marks offline', () async {
        var offline = 0;
        var online = 0;
        client.onOffline = () => offline++;
        client.onOnline = () => online++;
        adapter.onGet(
          '/slow',
          (s) => s.throws(
            0,
            DioException(
              requestOptions: RequestOptions(path: '/slow'),
              type: type,
            ),
          ),
        );
        await expectLater(
          client.get('/slow'),
          throwsA(
            isA<ApiError>()
                .having((e) => e.status, 'status', null)
                .having((e) => e.message, 'message', connectionErrorMessage),
          ),
        );
        expect((offline, online), (1, 0));
      });
    }
  });

  group('a response that is not the error shape', () {
    for (final (name, body) in [
      ('an HTML page', '<html>Internal Server Error</html>'),
      ('an empty body', ''),
    ]) {
      test('$name on a 500 says something went wrong, not offline', () async {
        var offline = 0;
        var online = 0;
        client.onOffline = () => offline++;
        client.onOnline = () => online++;
        adapter.onGet('/boom', (s) => s.reply(500, body));
        await expectLater(
          client.get('/boom'),
          throwsA(
            isA<ApiError>()
                .having((e) => e.status, 'status', 500)
                .having(
                  (e) => e.message,
                  'message',
                  'Something went wrong. Try again.',
                ),
          ),
        );
        expect((offline, online), (0, 1));
      });
    }
  });

  group('checkBaseUrl', () {
    test('release with http throws', () {
      expect(
        () => checkBaseUrl('http://api.example.com', release: true),
        throwsStateError,
      );
    });

    test('release with https is fine', () {
      checkBaseUrl('https://api.example.com', release: true);
    });

    test('debug with http is fine', () {
      checkBaseUrl('http://localhost:3100', release: false);
    });

    test('LAN build allows http to a private Wi-Fi address', () {
      for (final url in [
        'http://192.168.1.4:3100',
        'http://10.0.0.7:3100',
        'http://172.20.1.2:3100',
      ]) {
        checkBaseUrl(url, release: true, allowLanHttp: true);
      }
    });

    test('LAN build still refuses http to public hosts', () {
      for (final url in [
        'http://api.example.com',
        'http://8.8.8.8:3100',
        'http://172.32.0.1',
        'http://192.168.1.4.evil.com',
      ]) {
        expect(
          () => checkBaseUrl(url, release: true, allowLanHttp: true),
          throwsStateError,
          reason: url,
        );
      }
    });
  });

  group('paths', () {
    test(
      'absolute URLs and paths without a leading slash are refused',
      () async {
        for (final path in [
          'http://evil.example/groups',
          'https://evil.example',
          '//evil.example/groups',
          'groups',
          '',
        ]) {
          await expectLater(
            client.get(path),
            throwsArgumentError,
            reason: path,
          );
          await expectLater(
            client.post(path),
            throwsArgumentError,
            reason: path,
          );
          await expectLater(
            client.patch(path),
            throwsArgumentError,
            reason: path,
          );
          await expectLater(
            client.delete(path),
            throwsArgumentError,
            reason: path,
          );
        }
      },
    );
  });
}
