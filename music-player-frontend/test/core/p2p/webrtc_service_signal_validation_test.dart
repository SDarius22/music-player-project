import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/p2p/webrtc_service.dart';

void main() {
  group('WebRTCService signaling payload validation', () {
    test('parseSdpPayload returns parsed values for valid payload', () {
      final parsed = WebRTCService.parseSdpPayload({
        'sdp': 'v=0\no=- 1 2 IN IP4 127.0.0.1',
        'type': ' OFFER ',
        'offerId': 'abc-123',
      });

      expect(parsed, isNotNull);
      expect(parsed!.sdp, startsWith('v=0'));
      expect(parsed.type, 'offer');
      expect(parsed.offerId, 'abc-123');
    });

    test('parseSdpPayload rejects empty sdp', () {
      final parsed = WebRTCService.parseSdpPayload({
        'sdp': '   ',
        'type': 'answer',
      });

      expect(parsed, isNull);
    });

    test('parseSdpPayload rejects non-map payload', () {
      final parsed = WebRTCService.parseSdpPayload('invalid-payload');
      expect(parsed, isNull);
    });

    test('parseSdpPayload rejects unsupported type', () {
      final parsed = WebRTCService.parseSdpPayload({
        'sdp': 'v=0\no=- 1 2 IN IP4 127.0.0.1',
        'type': 'bogus',
      });

      expect(parsed, isNull);
    });

    test('parseSdpPayload rejects malformed SDP content', () {
      final parsed = WebRTCService.parseSdpPayload({
        'sdp': 'not-an-sdp',
        'type': 'answer',
      });

      expect(parsed, isNull);
    });

    test('parseSdpPayload accepts stringified JSON payload', () {
      final parsed = WebRTCService.parseSdpPayload(
        '{"sdp":"v=0\\r\\no=- 1 2 IN IP4 127.0.0.1","type":"answer","offerId":"xyz"}',
      );

      expect(parsed, isNotNull);
      expect(parsed!.type, 'answer');
      expect(parsed.offerId, 'xyz');
      expect(parsed.sdp, contains('\r\n'));
      expect(parsed.sdp, endsWith('\r\n'));
    });

    test('parseSdpPayload normalizes escaped newlines in map payload', () {
      final parsed = WebRTCService.parseSdpPayload({
        'sdp': r'v=0\r\no=- 1 2 IN IP4 127.0.0.1\n',
        'type': 'answer',
      });

      expect(parsed, isNotNull);
      expect(parsed!.sdp, contains('\r\n'));
      expect(parsed.sdp, isNot(contains(r'\n')));
      expect(parsed.offerId, isNull);
    });

    test('normalizePayload converts key types to string keys', () {
      final normalized = WebRTCService.normalizePayload({1: 'a', 'b': 2});

      expect(normalized, isNotNull);
      expect(normalized!['1'], 'a');
      expect(normalized['b'], 2);
    });

    test('normalizePayload returns null for non-map payload', () {
      expect(WebRTCService.normalizePayload('x'), isNull);
      expect(WebRTCService.normalizePayload(1), isNull);
      expect(WebRTCService.normalizePayload(null), isNull);
    });

    test('normalizePeerBufferMap keeps exact chunk indices per peer', () {
      final normalized = WebRTCService.normalizePeerBufferMap({
        'peer-1': [0, 2, '5'],
        'peer-2': '[3,4]',
        'peer-3': [],
      });

      expect(normalized['peer-1'], {0, 2, 5});
      expect(normalized['peer-2'], {3, 4});
      expect(normalized.containsKey('peer-3'), isFalse);
    });

    test(
      'normalizePeerBufferMap filters invalid and negative chunk values',
      () {
        final normalized = WebRTCService.normalizePeerBufferMap({
          'peer-a': [-1, '2', 'x', 4.9],
          'peer-b': 'not-json',
        });

        expect(normalized['peer-a'], {2, 4});
        expect(normalized.containsKey('peer-b'), isFalse);
      },
    );

    test(
      'parseSdpPayload accepts pranswer type and strips quoted sdp wrappers',
      () {
        final parsed = WebRTCService.parseSdpPayload({
          'sdp': '"v=0\\r\\no=- 1 2 IN IP4 127.0.0.1"',
          'type': 'pranswer',
        });

        expect(parsed, isNotNull);
        expect(parsed!.type, 'pranswer');
        expect(parsed.sdp, startsWith('v=0'));
        expect(parsed.sdp, endsWith('\r\n'));
      },
    );

    test('nonEmptyString trims whitespace and rejects empty values', () {
      expect(WebRTCService.nonEmptyString('  abc  '), 'abc');
      expect(WebRTCService.nonEmptyString('   '), isNull);
      expect(WebRTCService.nonEmptyString(10), isNull);
    });
  });
}
