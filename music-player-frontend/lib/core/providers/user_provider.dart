import 'package:flutter/foundation.dart';
import 'package:music_player_frontend/core/entities/user.dart';
import 'package:music_player_frontend/core/services/rest_clients/auth_service.dart';

enum AuthStatus { unknown, unauthenticated, authenticating, authenticated }

class UserProvider with ChangeNotifier {
  final AuthService _authService;

  AuthStatus _status = AuthStatus.unknown;
  User? _currentUser;
  String? _pendingEmail;

  UserProvider(this._authService);

  AuthStatus get status => _status;

  User? get currentUser => _currentUser;

  bool get isAuthenticated => _status == AuthStatus.authenticated;

  String? get pendingEmail => _pendingEmail;

  Future<void> initialize() async {
    final token = await _authService.accessToken;
    _status =
        (token != null && token.isNotEmpty)
            ? AuthStatus.authenticated
            : AuthStatus.unauthenticated;
    notifyListeners();
  }

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

  Future<bool> loginWithGoogle() async {
    _status = AuthStatus.authenticating;
    notifyListeners();

    _status = AuthStatus.unauthenticated;
    notifyListeners();
    return false;
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
