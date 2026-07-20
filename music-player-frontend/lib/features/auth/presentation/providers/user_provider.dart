import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:music_player_frontend/core/entities/user.dart';
import 'package:music_player_frontend/core/rest_clients/auth_service.dart';
import 'package:music_player_frontend/core/services/session_cleanup_service.dart';

enum AuthStatus { unknown, unauthenticated, authenticating, authenticated }

class UserProvider with ChangeNotifier {
  final AuthService _authService;
  final SessionCleanupService? _sessionCleanupService;

  AuthStatus _status = AuthStatus.unknown;
  User? _currentUser;
  String? _pendingEmail;
  Future<void>? _sessionCleanupFuture;

  UserProvider(this._authService, [this._sessionCleanupService]) {
    _authService.addListener(_handleAuthChange);
  }

  void _handleAuthChange() {
    if (!_authService.isLoggedIn && _status == AuthStatus.authenticated) {
      unawaited(_finishUnexpectedLogout());
    }
  }

  Future<void> _finishUnexpectedLogout() async {
    try {
      await _clearSessionData();
    } catch (_) {
      // Authentication is already gone; still remove the in-memory identity.
    } finally {
      _markUnauthenticated();
    }
  }

  @override
  void dispose() {
    _authService.removeListener(_handleAuthChange);
    super.dispose();
  }

  AuthStatus get status => _status;

  User? get currentUser => _currentUser;

  bool get isAuthenticated => _status == AuthStatus.authenticated;

  String? get pendingEmail => _pendingEmail;

  void setPendingEmail(String email) {
    _pendingEmail = email.trim();
    notifyListeners();
  }

  Future<bool> sendLoginCode(String email) async {
    final normalized = email.trim();
    _status = AuthStatus.authenticating;
    notifyListeners();
    try {
      final ok = await _authService.sendLoginCode(normalized);
      if (ok) _pendingEmail = normalized;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return ok;
    } catch (_) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyEmailCode({
    required String email,
    required String code,
  }) async {
    _status = AuthStatus.authenticating;
    notifyListeners();

    final ok = await _authService.verifyCode(email.trim(), code.trim());
    _status = ok ? AuthStatus.authenticated : AuthStatus.unauthenticated;

    if (ok) {
      final normalized = email.trim();
      _currentUser = User(
        email: normalized,
        isAdmin: await _authService.isAdmin,
      );
      _pendingEmail = null;
    }

    notifyListeners();
    return ok;
  }

  Future<bool> tryAutoLogin() async {
    _status = AuthStatus.authenticating;
    notifyListeners();

    final ok = await _authService.tryAutoLogin();
    _status = ok ? AuthStatus.authenticated : AuthStatus.unauthenticated;

    if (ok) {
      final normalized = (await _authService.userEmail)?.trim() ?? "unknown";
      _currentUser = User(
        email: normalized,
        isAdmin: await _authService.isAdmin,
      );
      _pendingEmail = null;
    }

    notifyListeners();
    return ok;
  }

  Future<void> logout() async {
    await _authService.logout();
    try {
      await _clearSessionData();
    } finally {
      _markUnauthenticated();
    }
  }

  Future<void> _clearSessionData() {
    final cleanupService = _sessionCleanupService;
    if (cleanupService == null) return Future.value();
    return _sessionCleanupFuture ??= cleanupService.clear().whenComplete(() {
      _sessionCleanupFuture = null;
    });
  }

  void _markUnauthenticated() {
    _currentUser = null;
    _pendingEmail = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  void setCurrentUser(User? user) {
    _currentUser = user;
    _status =
        user == null ? AuthStatus.unauthenticated : AuthStatus.authenticated;
    notifyListeners();
  }
}
