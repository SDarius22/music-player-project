import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:music_player_frontend/core/rest_clients/auth_service.dart';
import 'package:music_player_frontend/core/rest_clients/streaming_rest_client.dart';

/// AuthService stub that always reports a token so the REST client never takes
/// the refresh path. No platform channels are touched.
class _FakeAuthService extends AuthService {
  _FakeAuthService() : super(baseUrl: 'http://test');

  @override
  String? get accessToken => 'test-token';
}

/// Yields to the event loop a few times so any pending MockClient handlers run
/// up to their gate.
Future<void> pump([int times = 5]) async {
  for (var i = 0; i < times; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

int _chunkIndexOf(http.BaseRequest req) =>
    int.parse(req.url.pathSegments.last);

StreamingRestClient _client() =>
    StreamingRestClient(baseUrl: 'http://test', authService: _FakeAuthService());

void main() {
  group('StreamingRestClient server-pool prioritization', () {
    test('caps total concurrent server downloads at 3', () async {
      final gates = <int, Completer<void>>{};
      final started = <int>[];

      final mock = MockClient((req) async {
        final idx = _chunkIndexOf(req);
        started.add(idx);
        await (gates[idx] ??= Completer<void>()).future;
        return http.Response.bytes([0], 200);
      });

      await http.runWithClient(() async {
        final client = _client();
        final futures = [
          for (var i = 0; i < 6; i++) client.downloadChunkFallback('h', i),
        ];
        await pump();

        // Only 3 may be in flight; the rest queue.
        expect(started.length, 3);
        expect(started.toSet(), {0, 1, 2});

        // Freeing one slot admits exactly one more.
        gates[0]!.complete();
        await pump();
        expect(started.length, 4);
        expect(started.last, 3);

        for (var i = 0; i < 6; i++) {
          final gate = gates[i] ??= Completer<void>();
          if (!gate.isCompleted) gate.complete();
        }
        await Future.wait(futures);
      }, () => mock);
    });

    test('prefetch is limited to a single concurrent slot', () async {
      final gates = <int, Completer<void>>{};
      final started = <int>[];

      final mock = MockClient((req) async {
        final idx = _chunkIndexOf(req);
        started.add(idx);
        await (gates[idx] ??= Completer<void>()).future;
        return http.Response.bytes([0], 200);
      });

      await http.runWithClient(() async {
        final client = _client();
        final futures = [
          for (var i = 0; i < 3; i++)
            client.downloadChunkFallback('h', i, prefetch: true),
        ];
        await pump();

        // Even though the pool holds 3, prefetch may only use 1.
        expect(started.length, 1);
        expect(started.single, 0);

        gates[0]!.complete();
        await pump();
        expect(started.length, 2);

        for (var i = 0; i < 3; i++) {
          final gate = gates[i] ??= Completer<void>();
          if (!gate.isCompleted) gate.complete();
        }
        await Future.wait(futures);
      }, () => mock);
    });

    test('a freed slot goes to playback before prefetch', () async {
      final gates = <int, Completer<void>>{};
      final started = <int>[];

      final mock = MockClient((req) async {
        final idx = _chunkIndexOf(req);
        started.add(idx);
        await (gates[idx] ??= Completer<void>()).future;
        return http.Response.bytes([0], 200);
      });

      await http.runWithClient(() async {
        final client = _client();

        // Saturate the pool with 3 playback downloads.
        final saturating = [
          for (var i = 0; i < 3; i++) client.downloadChunkFallback('h', i),
        ];
        await pump();
        expect(started.toSet(), {0, 1, 2});

        // Enqueue a prefetch FIRST, then a playback request.
        final prefetchLate = client.downloadChunkFallback('h', 10, prefetch: true);
        final playbackLate = client.downloadChunkFallback('h', 20);
        await pump();
        // Pool is full: neither has started.
        expect(started.contains(10), isFalse);
        expect(started.contains(20), isFalse);

        // Free one slot: playback (20) must win over the earlier-queued
        // prefetch (10).
        gates[0]!.complete();
        await pump();
        expect(started.contains(20), isTrue);
        expect(started.contains(10), isFalse);

        for (final i in [1, 2, 10, 20]) {
          final gate = gates[i] ??= Completer<void>();
          if (!gate.isCompleted) gate.complete();
        }
        await Future.wait([...saturating, prefetchLate, playbackLate]);
      }, () => mock);
    });
  });

  group('StreamingRestClient downloadChunkFallback', () {
    test('returns the response body on 200', () async {
      await http.runWithClient(
        () async {
          final bytes = await _client().downloadChunkFallback('h', 0);
          expect(bytes, equals([7, 8, 9]));
        },
        () => MockClient((req) async => http.Response.bytes([7, 8, 9], 200)),
      );
    });

    test('throws on a non-200 (e.g. 504) response', () async {
      await http.runWithClient(
        () async {
          await expectLater(
            _client().downloadChunkFallback('h', 0),
            throwsA(isA<Exception>()),
          );
        },
        () => MockClient((req) async => http.Response('gateway timeout', 504)),
      );
    });

    test('a failed request still frees its slot for the next waiter', () async {
      var calls = 0;
      final mock = MockClient((req) async {
        calls++;
        // First call fails; subsequent succeed.
        if (calls == 1) return http.Response('', 504);
        return http.Response.bytes([1], 200);
      });

      await http.runWithClient(() async {
        final client = _client();
        await expectLater(
          client.downloadChunkFallback('h', 0),
          throwsA(isA<Exception>()),
        );
        // If the slot wasn't released in the finally block, this would hang.
        final bytes = await client.downloadChunkFallback('h', 1);
        expect(bytes, equals([1]));
      }, () => mock);
    });
  });
}
