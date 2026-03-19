import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class AuthService {
  final String baseUrl;
  final _storage = const FlutterSecureStorage();
  String? _cachedAccessToken;
  Timer? _refreshTimer;

  static const _refreshInterval = Duration(minutes: 10);

  AuthService({required this.baseUrl});

  void startTokenRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) async {
      if (isLoggedIn) {
        await refreshAccessToken();
      }
    });
  }

  void stopTokenRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  bool get isLoggedIn => _cachedAccessToken != null;

  Future<String?> get accessToken async {
    _cachedAccessToken ??= await _storage.read(key: 'access_token');
    return _cachedAccessToken;
  }

  Future<String?> get userEmail async {
    return await _storage.read(key: 'user_email');
  }

  Future<bool> get isAdmin async {
    final token = await accessToken;
    if (token == null) return false;
    final payload = _parseJwt(token);
    return payload['role'] == 'ADMIN';
  }

  Map<String, dynamic> _parseJwt(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      throw Exception('Invalid token');
    }

    final payload = _decodeBase64(parts[1]);
    final payloadMap = json.decode(payload);
    if (payloadMap is! Map<String, dynamic>) {
      throw Exception('Invalid payload');
    }

    return payloadMap;
  }

  String _decodeBase64(String str) {
    String output = str.replaceAll('-', '+').replaceAll('_', '/');
    switch (output.length % 4) {
      case 0:
        break;
      case 2:
        output += '==';
        break;
      case 3:
        output += '=';
        break;
      default:
        throw Exception('Illegal base64url string!"');
    }
    return utf8.decode(base64Url.decode(output));
  }

  Future<void> saveTokens(String access, String refresh) async {
    _cachedAccessToken = access;
    await _storage.write(key: 'access_token', value: access);
    await _storage.write(key: 'refresh_token', value: refresh);
    startTokenRefresh();
  }

  Future<bool> sendLoginCode(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/send-code'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Send Login Code Error: $e");
      return false;
    }
  }

  Future<bool> verifyCode(String email, String code) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'code': code}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await saveTokens(data['accessToken'], data['refreshToken']);
        await _storage.write(key: 'user_email', value: email);
        return true;
      }
    } catch (e) {
      return false;
    }
    return false;
  }

  Future<String?> refreshAccessToken() async {
    final refresh = await _storage.read(key: 'refresh_token');
    if (refresh == null) return null;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refresh}),
      );

      debugPrint(
        "Refresh token response: ${response.statusCode} - ${response.body}",
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await saveTokens(data['accessToken'], data['refreshToken'] ?? refresh);
        return data['accessToken'];
      } else {
        await logout();
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  Future<bool> tryAutoLogin() async {
    final refresh = await _storage.read(key: 'refresh_token');

    if (refresh == null) {
      return false;
    }

    final newToken = await refreshAccessToken();
    return newToken != null;
  }

  Future<void> logout() async {
    stopTokenRefresh();
    _cachedAccessToken = null;
    await _storage.deleteAll();
  }
}
