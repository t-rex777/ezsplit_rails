import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';

import 'api_error.dart';

const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:3100',
);

const Map<String, String> apiHeaders = {
  'Accept': 'application/json',
  'Content-Type': 'application/json',
};

class ApiClient {
  ApiClient(
    this._dio, {
    this.cookieJar,
    this.onUnauthorized,
    this.onOffline,
    this.onOnline,
  });

  final Dio _dio;

  /// The jar behind [_dio], when there is one, so startup can hand it to repositories.
  final CookieJar? cookieJar;

  /// Fires on a 401, or a redirect to /session/new, except for a failed login.
  void Function()? onUnauthorized;

  /// Fires when a request gets no response at all.
  void Function()? onOffline;

  /// Fires when a request gets any response, whatever its status.
  void Function()? onOnline;

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) => _send('GET', path, query: query);

  Future<Map<String, dynamic>> post(String path, {Object? body}) =>
      _send('POST', path, body: body);

  Future<Map<String, dynamic>> patch(String path, {Object? body}) =>
      _send('PATCH', path, body: body);

  Future<Map<String, dynamic>> delete(String path, {Object? body}) =>
      _send('DELETE', path, body: body);

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) async {
    Response<dynamic> response;
    try {
      response = await _dio.request<dynamic>(
        path,
        data: body,
        queryParameters: query,
        options: Options(method: method, headers: apiHeaders),
      );
    } on DioException catch (e) {
      final r = e.response;
      if (r == null) {
        onOffline?.call();
        throw const ApiError(message: connectionErrorMessage);
      }
      response = r;
    }
    onOnline?.call();

    final status = response.statusCode ?? 0;
    final data = response.data;
    if (status >= 200 && status < 300) {
      return data is Map<String, dynamic> ? data : <String, dynamic>{};
    }

    if (status >= 300 && status < 400) {
      final location = response.headers.value('location') ?? '';
      if (Uri.tryParse(location)?.path.endsWith('/session/new') ?? false) {
        _fireUnauthorized(method, path);
        throw const ApiError(
          status: 401,
          message: 'Your session expired. Log in again.',
        );
      }
      throw ApiError(status: status, message: _messageFrom(data));
    }

    if (status == 401) _fireUnauthorized(method, path);
    throw ApiError(status: status, message: _messageFrom(data));
  }

  void _fireUnauthorized(String method, String path) {
    // A wrong password is a login error, not an expired session.
    if (method == 'POST' && path == '/session') return;
    onUnauthorized?.call();
  }

  String _messageFrom(dynamic data) {
    if (data is Map) {
      final errors = data['errors'];
      if (errors is List && errors.isNotEmpty) return errors.first.toString();
      final message = data['message'];
      if (message is String && message.isNotEmpty) return message;
    }
    return connectionErrorMessage;
  }
}

Future<ApiClient> createApiClient({
  required String baseUrl,
  void Function()? onUnauthorized,
}) async {
  final dir = await getApplicationDocumentsDirectory();
  final jar = PersistCookieJar(storage: FileStorage('${dir.path}/.cookies/'));
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      headers: apiHeaders,
      followRedirects: false,
      validateStatus: (status) => status != null && status < 400,
    ),
  );
  dio.interceptors.add(CookieManager(jar));
  return ApiClient(dio, cookieJar: jar, onUnauthorized: onUnauthorized);
}
