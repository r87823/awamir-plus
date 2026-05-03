import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/environment.dart';
import '../errors/app_exception.dart';
import 'session_cookie_store.dart';

class ApiClient {
  ApiClient({
    http.Client? httpClient,
    SessionCookieStore cookieStore = const SessionCookieStore(),
    String baseUrl = AppEnvironment.baseUrl,
    String apiPrefix = AppEnvironment.apiPrefix,
    Duration timeout = AppEnvironment.requestTimeout,
  }) : _httpClient = httpClient ?? http.Client(),
       _cookieStore = cookieStore,
       _baseUri = Uri.parse(baseUrl),
       _apiPrefix = apiPrefix,
       _timeout = timeout;

  final http.Client _httpClient;
  final SessionCookieStore _cookieStore;
  final Uri _baseUri;
  final String _apiPrefix;
  final Duration _timeout;

  Future<T> get<T>(
    String method, {
    Map<String, String?> queryParameters = const {},
    T Function(Object? data)? parser,
  }) {
    return _send<T>(
      'GET',
      method,
      queryParameters: queryParameters,
      parser: parser,
    );
  }

  Future<T> post<T>(
    String method, {
    Map<String, dynamic> body = const {},
    T Function(Object? data)? parser,
  }) {
    return _send<T>('POST', method, body: body, parser: parser);
  }

  Future<T> multipart<T>(
    String method, {
    Map<String, String> fields = const {},
    List<http.MultipartFile> files = const [],
    T Function(Object? data)? parser,
  }) async {
    final request = http.MultipartRequest('POST', _methodUri(method));
    request.fields.addAll(fields);
    request.files.addAll(files);

    final cookieHeader = await _cookieStore.readCookieHeader();
    if (cookieHeader != null && cookieHeader.isNotEmpty) {
      request.headers['Cookie'] = cookieHeader;
    }

    try {
      final streamed = await _httpClient.send(request).timeout(_timeout);
      final response = await http.Response.fromStream(streamed);
      await _captureCookies(response);
      return _decodeResponse(response, parser);
    } on TimeoutException catch (error) {
      throw NetworkException(
        'انتهت مهلة الاتصال بالخادم',
        code: 'request_timeout',
        cause: error,
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw NetworkException(
        'تعذر الاتصال بالخادم',
        code: 'network_error',
        cause: error,
      );
    }
  }

  Future<void> clearSession() => _cookieStore.clear();

  Future<T> _send<T>(
    String httpMethod,
    String method, {
    Map<String, String?> queryParameters = const {},
    Map<String, dynamic> body = const {},
    T Function(Object? data)? parser,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    final cookieHeader = await _cookieStore.readCookieHeader();
    if (cookieHeader != null && cookieHeader.isNotEmpty) {
      headers['Cookie'] = cookieHeader;
    }

    final uri = _methodUri(method, queryParameters: queryParameters);

    try {
      final response =
          await (httpMethod == 'GET'
                  ? _httpClient.get(uri, headers: headers)
                  : _httpClient.post(
                      uri,
                      headers: headers,
                      body: jsonEncode(body),
                    ))
              .timeout(_timeout);

      await _captureCookies(response);
      return _decodeResponse(response, parser);
    } on TimeoutException catch (error) {
      throw NetworkException(
        'انتهت مهلة الاتصال بالخادم',
        code: 'request_timeout',
        cause: error,
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw NetworkException(
        'تعذر الاتصال بالخادم',
        code: 'network_error',
        cause: error,
      );
    }
  }

  Uri _methodUri(
    String method, {
    Map<String, String?> queryParameters = const {},
  }) {
    final normalizedPrefix = _apiPrefix.startsWith('/')
        ? _apiPrefix
        : '/$_apiPrefix';
    final normalizedMethod = method.startsWith('/')
        ? method.substring(1)
        : method;
    final path = '$normalizedPrefix/$normalizedMethod';
    final query = <String, String>{};
    for (final entry in queryParameters.entries) {
      final value = entry.value;
      if (value != null) query[entry.key] = value;
    }
    return _baseUri.replace(
      path: path,
      queryParameters: query.isEmpty ? null : query,
    );
  }

  Future<void> _captureCookies(http.Response response) async {
    final setCookie = response.headers['set-cookie'];
    if (setCookie == null || setCookie.isEmpty) return;

    final existingHeader = await _cookieStore.readCookieHeader();
    final cookies = _parseCookieHeader(existingHeader);
    for (final cookie in _splitSetCookieHeader(setCookie)) {
      final pair = cookie.split(';').first.trim();
      final separator = pair.indexOf('=');
      if (separator <= 0) continue;
      final name = pair.substring(0, separator);
      final value = pair.substring(separator + 1);
      cookies[name] = value;
    }
    final cookieHeader = cookies.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join('; ');
    await _cookieStore.saveCookieHeader(cookieHeader);
  }

  Map<String, String> _parseCookieHeader(String? header) {
    final cookies = <String, String>{};
    if (header == null || header.trim().isEmpty) return cookies;
    for (final part in header.split(';')) {
      final pair = part.trim();
      final separator = pair.indexOf('=');
      if (separator <= 0) continue;
      cookies[pair.substring(0, separator)] = pair.substring(separator + 1);
    }
    return cookies;
  }

  List<String> _splitSetCookieHeader(String header) {
    return header.split(RegExp(r',\s*(?=[^;,]+=)'));
  }

  T _decodeResponse<T>(
    http.Response response,
    T Function(Object? data)? parser,
  ) {
    final decoded = _tryDecodeJson(response.body);
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw NetworkException(
        _frappeErrorMessage(decoded) ?? 'انتهت الجلسة أو لا تملك الصلاحية',
        code: response.statusCode == 401 ? 'unauthorized' : 'forbidden',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw NetworkException(
        _frappeErrorMessage(decoded) ?? 'فشل الطلب من الخادم',
        code: 'http_${response.statusCode}',
      );
    }

    final payload =
        decoded is Map<String, dynamic> && decoded.containsKey('message')
        ? decoded['message']
        : decoded;
    if (parser != null) return parser(payload);
    return payload as T;
  }

  Object? _tryDecodeJson(String body) {
    if (body.trim().isEmpty) return null;
    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }

  String? _frappeErrorMessage(Object? decoded) {
    if (decoded is! Map<String, dynamic>) return null;
    final serverMessages = decoded['_server_messages'];
    if (serverMessages is String && serverMessages.isNotEmpty) {
      try {
        final messages = jsonDecode(serverMessages);
        if (messages is List && messages.isNotEmpty) {
          final first = jsonDecode(messages.first.toString());
          if (first is Map && first['message'] != null) {
            return _stripHtml(first['message'].toString());
          }
        }
      } catch (_) {
        return _stripHtml(serverMessages);
      }
    }
    for (final key in ['message', 'exception', 'exc_type']) {
      final value = decoded[key];
      if (value is String && value.trim().isNotEmpty) {
        return _stripHtml(value);
      }
    }
    return null;
  }

  String _stripHtml(String value) {
    return value.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  }
}
