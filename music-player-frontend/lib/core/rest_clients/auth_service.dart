import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

class AuthService extends ChangeNotifier {
  static final _logger = Logger('AuthService');

  final String baseUrl;
  final _storage = const FlutterSecureStorage();
  String? _cachedAccessToken;
  Timer? _refreshTimer;
  bool _sessionExpired = false;

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

  String? get accessToken {
    return _cachedAccessToken;
  }

  Future<String?> get userEmail async {
    return await _storage.read(key: 'user_email');
  }

  Future<bool> get isAdmin async {
    final token = accessToken;
    if (token == null) return false;
    final payload = _parseJwt(token);
    return payload['role'] == 'ADMIN';
  }

  int? get userId {
    final token = accessToken;
    if (token == null) return null;
    final payload = _parseJwt(token);
    final id = payload['userId'];
    if (id is int) return id;
    if (id is num) return id.toInt();
    return null;
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
    final wasNull = _cachedAccessToken == null;
    _cachedAccessToken = access;
    _sessionExpired = false;
    await _storage.write(key: 'access_token', value: access);
    await _storage.write(key: 'refresh_token', value: refresh);
    startTokenRefresh();
    if (wasNull) notifyListeners();
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
      _logger.warning('Send Login Code Error', e);
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

    if (_isJwtExpired(refresh)) {
      await _expireSession();
      return null;
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refresh}),
      );

      _logger.fine(
        "Refresh token response: ${response.statusCode} - ${response.body}",
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await saveTokens(data['accessToken'], data['refreshToken'] ?? refresh);
        return data['accessToken'];
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        await _expireSession();
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
    if (newToken != null) {
      return true;
    }

    if (_sessionExpired) return false;

    final storedAccess = await _storage.read(key: 'access_token');
    if (storedAccess != null) {
      _logger.info(
        'Refresh failed – restoring cached access token for offline use.',
      );
      _cachedAccessToken = storedAccess;
      startTokenRefresh();
      notifyListeners();
      return true;
    }

    return false;
  }

  Future<void> logout() async {
    stopTokenRefresh();
    final hadToken = _cachedAccessToken != null;
    _cachedAccessToken = null;
    await _storage.deleteAll();
    if (hadToken) notifyListeners();
  }

  bool _isJwtExpired(String token) {
    try {
      final expiry = _parseJwt(token)['exp'];
      if (expiry is! num) return true;
      return DateTime.now().millisecondsSinceEpoch >= expiry.toInt() * 1000;
    } catch (_) {
      return true;
    }
  }

  Future<void> _expireSession() async {
    _sessionExpired = true;
    stopTokenRefresh();
    final hadToken = _cachedAccessToken != null;
    _cachedAccessToken = null;
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
    if (hadToken) notifyListeners();
  }
}
