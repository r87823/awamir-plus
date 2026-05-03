import 'package:awamir_plus_mobile/core/errors/app_exception.dart';
import 'package:awamir_plus_mobile/core/network/api_client.dart';
import 'package:awamir_plus_mobile/core/network/session_cookie_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('ApiClient يتعامل مع 403 بشكل صحيح', () async {
    final client = ApiClient(
      baseUrl: 'https://example.com',
      cookieStore: _MemoryCookieStore(),
      httpClient: MockClient(
        (_) async => http.Response(
          '{"exception":"Forbidden"}',
          403,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );

    expect(
      () => client.get<Object?>('awamir_plus.api.auth.get_current_user'),
      throwsA(
        isA<NetworkException>().having(
          (error) => error.code,
          'code',
          'forbidden',
        ),
      ),
    );
  });
}

class _MemoryCookieStore extends SessionCookieStore {
  _MemoryCookieStore();

  String? value;

  @override
  Future<String?> readCookieHeader() async => value;

  @override
  Future<void> saveCookieHeader(String cookieHeader) async {
    value = cookieHeader;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}
