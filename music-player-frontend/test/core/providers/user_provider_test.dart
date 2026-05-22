import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:music_player_frontend/core/entities/user.dart';
import 'package:music_player_frontend/core/providers/user_provider.dart';
import 'package:music_player_frontend/core/rest_clients/auth_service.dart';

import 'user_provider_test.mocks.dart';

@GenerateNiceMocks([MockSpec<AuthService>()])
void main() {
  late MockAuthService mockAuthService;
  late UserProvider provider;

  setUp(() {
    mockAuthService = MockAuthService();
    provider = UserProvider(mockAuthService);
  });

  group('initial state', () {
    test('status starts as unknown', () {
      expect(provider.status, AuthStatus.unknown);
    });

    test('currentUser is null initially', () {
      expect(provider.currentUser, isNull);
    });

    test('isAuthenticated is false initially', () {
      expect(provider.isAuthenticated, isFalse);
    });
  });

  group('setPendingEmail', () {
    test('trims and stores the email', () {
      provider.setPendingEmail('  test@example.com  ');

      expect(provider.pendingEmail, 'test@example.com');
    });
  });

  group('sendLoginCode', () {
    test(
      'returns true and stores pendingEmail when service succeeds',
      () async {
        when(
          mockAuthService.sendLoginCode('user@example.com'),
        ).thenAnswer((_) async => true);

        final result = await provider.sendLoginCode('user@example.com');

        expect(result, isTrue);
        expect(provider.pendingEmail, 'user@example.com');
        expect(provider.status, AuthStatus.unauthenticated);
      },
    );

    test('returns false when service returns false', () async {
      when(mockAuthService.sendLoginCode(any)).thenAnswer((_) async => false);

      final result = await provider.sendLoginCode('bad@example.com');

      expect(result, isFalse);
      expect(provider.status, AuthStatus.unauthenticated);
    });

    test('returns false and does not throw when service throws', () async {
      when(mockAuthService.sendLoginCode(any)).thenThrow(Exception('network'));

      final result = await provider.sendLoginCode('error@example.com');

      expect(result, isFalse);
      expect(provider.status, AuthStatus.unauthenticated);
    });

    test('notifies listeners during and after the call', () async {
      final statuses = <AuthStatus>[];
      provider.addListener(() => statuses.add(provider.status));
      when(mockAuthService.sendLoginCode(any)).thenAnswer((_) async => true);

      await provider.sendLoginCode('user@example.com');

      expect(statuses, contains(AuthStatus.authenticating));
      expect(statuses.last, AuthStatus.unauthenticated);
    });
  });

  group('verifyEmailCode', () {
    test('sets status to authenticated and creates user on success', () async {
      when(
        mockAuthService.verifyCode('user@example.com', '123456'),
      ).thenAnswer((_) async => true);
      when(mockAuthService.isAdmin).thenAnswer((_) async => false);

      final result = await provider.verifyEmailCode(
        email: 'user@example.com',
        code: '123456',
      );

      expect(result, isTrue);
      expect(provider.status, AuthStatus.authenticated);
      expect(provider.isAuthenticated, isTrue);
      expect(provider.currentUser, isNotNull);
      expect(provider.currentUser!.email, 'user@example.com');
      expect(provider.currentUser!.isAdmin, isFalse);
      expect(provider.pendingEmail, isNull);
    });

    test('sets status to unauthenticated on failure', () async {
      when(mockAuthService.verifyCode(any, any)).thenAnswer((_) async => false);

      final result = await provider.verifyEmailCode(
        email: 'user@example.com',
        code: 'wrong',
      );

      expect(result, isFalse);
      expect(provider.status, AuthStatus.unauthenticated);
      expect(provider.currentUser, isNull);
    });

    test('marks user as admin when auth service reports admin role', () async {
      when(mockAuthService.verifyCode(any, any)).thenAnswer((_) async => true);
      when(mockAuthService.isAdmin).thenAnswer((_) async => true);

      await provider.verifyEmailCode(email: 'admin@example.com', code: '000');

      expect(provider.currentUser!.isAdmin, isTrue);
    });

    test('trims email and code before delegating to auth service', () async {
      when(
        mockAuthService.verifyCode('user@example.com', '123456'),
      ).thenAnswer((_) async => true);
      when(mockAuthService.isAdmin).thenAnswer((_) async => false);

      final result = await provider.verifyEmailCode(
        email: '  user@example.com  ',
        code: ' 123456 ',
      );

      expect(result, isTrue);
      verify(
        mockAuthService.verifyCode('user@example.com', '123456'),
      ).called(1);
    });
  });

  group('tryAutoLogin', () {
    test('sets authenticated and builds user when service succeeds', () async {
      when(mockAuthService.tryAutoLogin()).thenAnswer((_) async => true);
      when(
        mockAuthService.userEmail,
      ).thenAnswer((_) async => 'saved@example.com');
      when(mockAuthService.isAdmin).thenAnswer((_) async => false);

      final result = await provider.tryAutoLogin();

      expect(result, isTrue);
      expect(provider.isAuthenticated, isTrue);
      expect(provider.currentUser!.email, 'saved@example.com');
    });

    test('sets unauthenticated when service returns false', () async {
      when(mockAuthService.tryAutoLogin()).thenAnswer((_) async => false);

      final result = await provider.tryAutoLogin();

      expect(result, isFalse);
      expect(provider.status, AuthStatus.unauthenticated);
      expect(provider.currentUser, isNull);
    });

    test(
      'uses fallback email when auto-login has no stored userEmail',
      () async {
        when(mockAuthService.tryAutoLogin()).thenAnswer((_) async => true);
        when(mockAuthService.userEmail).thenAnswer((_) async => null);
        when(mockAuthService.isAdmin).thenAnswer((_) async => false);

        final result = await provider.tryAutoLogin();

        expect(result, isTrue);
        expect(provider.currentUser?.email, 'unknown');
      },
    );
  });

  group('logout', () {
    test('clears user and sets status to unauthenticated', () async {
      when(mockAuthService.verifyCode(any, any)).thenAnswer((_) async => true);
      when(mockAuthService.isAdmin).thenAnswer((_) async => false);
      await provider.verifyEmailCode(email: 'user@example.com', code: '123');

      when(mockAuthService.logout()).thenAnswer((_) async {});

      await provider.logout();

      expect(provider.currentUser, isNull);
      expect(provider.status, AuthStatus.unauthenticated);
      expect(provider.isAuthenticated, isFalse);
      verify(mockAuthService.logout()).called(1);
    });
  });

  group('setCurrentUser', () {
    test('sets user and marks authenticated', () {
      provider.setCurrentUser(const User(email: 'manual@example.com'));

      expect(provider.isAuthenticated, isTrue);
      expect(provider.currentUser!.email, 'manual@example.com');
    });

    test('clears user and marks unauthenticated when null passed', () {
      provider.setCurrentUser(null);

      expect(provider.isAuthenticated, isFalse);
      expect(provider.currentUser, isNull);
    });
  });
}
