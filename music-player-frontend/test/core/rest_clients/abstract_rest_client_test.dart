import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:music_player_frontend/core/rest_clients/abstract_rest_client.dart';
import 'package:music_player_frontend/core/rest_clients/auth_service.dart';

class _Client extends AbstractRestClient {
  _Client() {
    baseUrl = 'http://example.test';
    authService = AuthService(baseUrl: baseUrl);
  }
}

void main() {
  test('put sends JSON content and bearer authorization', () async {
    final transport = MockClient((request) async {
      expect(request.method, 'PUT');
      expect(request.url.path, '/resource');
      expect(request.headers['content-type'], 'application/json');
      expect(request.headers['authorization'], 'Bearer ');
      expect(jsonDecode(request.body), {'name': 'updated'});
      return http.Response('ok', 200);
    });

    final response = await http.runWithClient(
      () => _Client().put('/resource', {'name': 'updated'}),
      () => transport,
    );

    expect(response.statusCode, 200);
  });
}
