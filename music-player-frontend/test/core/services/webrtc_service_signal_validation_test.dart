import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/services/webrtc_service.dart';

void main() {
  group('WebRTCService signaling payload validation', () {
    test('parseSdpPayload returns parsed values for valid payload', () {
      final parsed = WebRTCService.parseSdpPayload({
        'sdp': 'v=0\no=- 1 2 IN IP4 127.0.0.1',
        'type': ' OFFER ',
      });

      expect(parsed, isNotNull);
      expect(parsed!.sdp, startsWith('v=0'));
      expect(parsed.type, 'offer');
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
        '{"sdp":"v=0\\r\\no=- 1 2 IN IP4 127.0.0.1","type":"answer"}',
      );

      expect(parsed, isNotNull);
      expect(parsed!.type, 'answer');
      expect(parsed.sdp, contains('\n'));
      expect(parsed.sdp, isNot(contains(r'\r\n')));
    });

    test('parseSdpPayload normalizes escaped newlines in map payload', () {
      final parsed = WebRTCService.parseSdpPayload({
        'sdp': r'v=0\r\no=- 1 2 IN IP4 127.0.0.1\n',
        'type': 'answer',
      });

      expect(parsed, isNotNull);
      expect(parsed!.sdp, contains('\n'));
      expect(parsed.sdp, isNot(contains(r'\n')));
    });

    test('normalizePayload converts key types to string keys', () {
      final normalized = WebRTCService.normalizePayload({1: 'a', 'b': 2});

      expect(normalized, isNotNull);
      expect(normalized!['1'], 'a');
      expect(normalized['b'], 2);
    });
  });
}

