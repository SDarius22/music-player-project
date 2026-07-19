import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/p2p/protocol/chunk_assembly.dart';
import 'package:music_player_frontend/core/p2p/protocol/peer_stats.dart';
import 'package:music_player_frontend/core/p2p/protocol/sdp_summary.dart';

void main() {
  group('ChunkAssembly', () {
    test('assembles fragments by index and rejects duplicates', () {
      final assembly = ChunkAssembly(3);

      expect(assembly.addFragment(2, Uint8List.fromList([5, 6])), isTrue);
      expect(assembly.addFragment(0, Uint8List.fromList([1, 2])), isTrue);
      expect(assembly.addFragment(0, Uint8List.fromList([9])), isFalse);
      expect(assembly.isComplete, isFalse);
      expect(assembly.assemble(), isNull);

      expect(assembly.addFragment(1, Uint8List.fromList([3, 4])), isTrue);
      expect(assembly.isComplete, isTrue);
      expect(assembly.totalBytes, 6);
      expect(assembly.assemble(), orderedEquals([1, 2, 3, 4, 5, 6]));
    });

    test(
      'returns null when the fragment count is met with an invalid index',
      () {
        final assembly =
            ChunkAssembly(2)
              ..addFragment(0, Uint8List.fromList([1]))
              ..addFragment(2, Uint8List.fromList([3]));

        expect(assembly.isComplete, isTrue);
        expect(assembly.assemble(), isNull);
      },
    );
  });

  test('PeerStats updates latency, throughput, successes, and failures', () {
    final stats = PeerStats();
    expect(stats.successRate, 0.5);
    expect(stats.score, closeTo(0.000998, 0.000001));

    stats.recordRtt(100);
    expect(stats.rttMs, 420);

    stats.recordDelivery(1000, 0);
    expect(stats.successes, 1);
    expect(stats.throughputBytesPerMs, closeTo(200.0008, 0.0001));
    expect(stats.successRate, 1);

    stats.recordFailure();
    expect(stats.failures, 1);
    expect(stats.successRate, 0.5);
    expect(stats.score, greaterThan(0));
  });

  group('SdpSummary', () {
    test(
      'describes media, ICE, fingerprint, and data-channel capabilities',
      () {
        const sdp =
            'v=0\r\n'
            'a=ice-ufrag:test\r\n'
            'a=fingerprint:sha-256 AA\r\n'
            'm=audio 9 UDP/TLS/RTP/SAVPF 111\r\n'
            'm=application 9 UDP/DTLS/SCTP webrtc-datachannel\r\n'
            'a=sctp-port:5000';
        final summary = SdpSummary.fromSdp(type: 'offer', sdp: sdp);

        expect(summary.type, 'offer');
        expect(summary.length, sdp.length);
        expect(summary.mediaSections, 2);
        expect(summary.hasDataChannel, isTrue);
        expect(summary.hasIceUfrag, isTrue);
        expect(summary.hasFingerprint, isTrue);
        expect(
          summary.toString(),
          'type=offer len=${sdp.length} m=2 data=true ufrag=true fp=true',
        );
      },
    );

    test('reports absent optional capabilities', () {
      final summary = SdpSummary.fromSdp(type: 'answer', sdp: 'v=0');

      expect(summary.mediaSections, 0);
      expect(summary.hasDataChannel, isFalse);
      expect(summary.hasIceUfrag, isFalse);
      expect(summary.hasFingerprint, isFalse);
    });
  });
}
