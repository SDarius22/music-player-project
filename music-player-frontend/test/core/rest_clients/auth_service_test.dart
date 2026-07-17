import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:music_player_frontend/core/rest_clients/auth_service.dart';

String _jwt(Map<String, Object?> payload) {
  final header = base64Url.encode(utf8.encode('{}')).replaceAll('=', '');
  final body = base64Url
      .encode(utf8.encode(jsonEncode(payload)))
      .replaceAll('=', '');
  return '$header.$body.signature';
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('saves, exposes, decodes, and clears tokens', () async {
    final service = AuthService(baseUrl: 'http://test');
    addTearDown(service.stopTokenRefresh);
    var notifications = 0;
    service.addListener(() => notifications++);
    final token = _jwt({'role': 'ADMIN', 'userId': 7});

    await service.saveTokens(token, _jwt({'exp': 4102444800}));
    expect(service.isLoggedIn, isTrue);
    expect(service.accessToken, token);
    expect(await service.isAdmin, isTrue);
    expect(service.userId, 7);
    expect(notifications, 1);

    await service.logout();
    expect(service.isLoggedIn, isFalse);
    expect(service.userId, isNull);
    expect(await service.isAdmin, isFalse);
    expect(notifications, 2);
  });

  test('supports numeric ids and rejects malformed JWT data', () async {
    final service = AuthService(baseUrl: 'http://test');
    addTearDown(service.stopTokenRefresh);
    await service.saveTokens(_jwt({'userId': 7.8}), 'refresh');
    expect(service.userId, 7);
    await service.saveTokens('not-a-jwt', 'refresh');
    expect(() => service.userId, throwsException);
  });

  test('sendLoginCode returns status and handles request errors', () async {
    final service = AuthService(baseUrl: 'http://test');
    await http.runWithClient(
      () async {
        expect(await service.sendLoginCode('a@example.com'), isTrue);
      },
      () => MockClient((request) async {
        expect(jsonDecode(request.body)['email'], 'a@example.com');
        return http.Response('', 200);
      }),
    );
    await http.runWithClient(() async {
      expect(await service.sendLoginCode('a@example.com'), isFalse);
    }, () => MockClient((_) async => http.Response('', 500)));
  });

  test('verifyCode stores tokens and email on success', () async {
    final service = AuthService(baseUrl: 'http://test');
    addTearDown(service.stopTokenRefresh);
    final access = _jwt({'userId': 2});
    await http.runWithClient(
      () async {
        expect(await service.verifyCode('a@example.com', '1234'), isTrue);
      },
      () => MockClient(
        (_) async => http.Response(
          jsonEncode({'accessToken': access, 'refreshToken': 'refresh'}),
          200,
        ),
      ),
    );
    expect(service.accessToken, access);
    expect(await service.userEmail, 'a@example.com');

    await http.runWithClient(() async {
      expect(await service.verifyCode('a@example.com', 'bad'), isFalse);
    }, () => MockClient((_) async => http.Response('', 401)));
  });

  test(
    'refreshes a valid token and auto-login restores stored access',
    () async {
      final refresh = _jwt({'exp': 4102444800});
      final access = _jwt({'userId': 3});
      FlutterSecureStorage.setMockInitialValues({'refresh_token': refresh});
      final service = AuthService(baseUrl: 'http://test');
      addTearDown(service.stopTokenRefresh);
      await http.runWithClient(
        () async {
          expect(await service.refreshAccessToken(), access);
        },
        () => MockClient(
          (_) async => http.Response(jsonEncode({'accessToken': access}), 200),
        ),
      );
      expect(service.accessToken, access);

      service.stopTokenRefresh();
      FlutterSecureStorage.setMockInitialValues({
        'refresh_token': refresh,
        'access_token': access,
      });
      final offline = AuthService(baseUrl: 'http://test');
      addTearDown(offline.stopTokenRefresh);
      await http.runWithClient(() async {
        expect(await offline.tryAutoLogin(), isTrue);
      }, () => MockClient((_) async => http.Response('', 500)));
      expect(offline.accessToken, access);
    },
  );

  test(
    'missing or expired refresh tokens fail and expire the session',
    () async {
      final missing = AuthService(baseUrl: 'http://test');
      expect(await missing.refreshAccessToken(), isNull);
      expect(await missing.tryAutoLogin(), isFalse);

      final expired = _jwt({'exp': 1});
      FlutterSecureStorage.setMockInitialValues({'refresh_token': expired});
      final service = AuthService(baseUrl: 'http://test');
      expect(await service.refreshAccessToken(), isNull);
      expect(await service.tryAutoLogin(), isFalse);
    },
  );

  test('unauthorized refresh expires a previously logged-in session', () async {
    final refresh = _jwt({'exp': 4102444800});
    FlutterSecureStorage.setMockInitialValues({'refresh_token': refresh});
    final service = AuthService(baseUrl: 'http://test');
    addTearDown(service.stopTokenRefresh);
    await service.saveTokens(_jwt({'userId': 1}), refresh);
    await http.runWithClient(() async {
      expect(await service.refreshAccessToken(), isNull);
    }, () => MockClient((_) async => http.Response('', 401)));
    expect(service.isLoggedIn, isFalse);
  });
}
