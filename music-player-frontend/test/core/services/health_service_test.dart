import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/rest_clients/health_rest_client.dart';
import 'package:music_player_frontend/core/services/health_service.dart';

class _FakeHealthRestClient extends Fake implements HealthRestClient {
  final List<bool> checks = [];
  bool nextValue = true;

  @override
  Future<bool> checkHealth() async {
    checks.add(nextValue);
    return nextValue;
  }
}

void main() {
  group('HealthService', () {
    test('runs initial health check on construction', () {
      fakeAsync((async) {
        final rest = _FakeHealthRestClient()..nextValue = false;
        final service = HealthService(rest);

        async.flushMicrotasks();

        expect(rest.checks, [false]);
        expect(service.isHealthy.value, isFalse);
        service.dispose();
      });
    });

    test('periodically re-checks health every 30 seconds', () {
      fakeAsync((async) {
        final rest = _FakeHealthRestClient()..nextValue = true;
        final service = HealthService(rest);

        async.flushMicrotasks();
        rest.nextValue = false;
        async.elapse(const Duration(seconds: 30));
        async.flushMicrotasks();

        expect(rest.checks, [true, false]);
        expect(service.isHealthy.value, isFalse);
        service.dispose();
      });
    });

    test('dispose cancels future periodic checks', () {
      fakeAsync((async) {
        final rest = _FakeHealthRestClient();
        final service = HealthService(rest);

        async.flushMicrotasks();
        service.dispose();
        async.elapse(const Duration(minutes: 2));
        async.flushMicrotasks();

        expect(rest.checks.length, 1);
      });
    });
  });
}
