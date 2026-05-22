import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/services/webrtc/data_channel_chunk_codec.dart';

void main() {
  group('DataChannelChunkCodec', () {
    const fileHash =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

    test('round-trips a legacy single-packet chunk', () {
      final data = Uint8List.fromList([1, 2, 3, 4]);

      final packets = DataChannelChunkCodec.encode(
        fileHash: fileHash,
        chunkIndex: 7,
        data: data,
      );

      expect(packets, hasLength(1));
      final decoded = DataChannelChunkCodec.decode(packets.single);

      expect(decoded, isA<DecodedChunkPacket>());
      final packet = decoded as DecodedChunkPacket;
      expect(packet.fileHash, fileHash);
      expect(packet.chunkIndex, 7);
      expect(packet.data, data);
    });

    test('splits and decodes a fragmented chunk', () {
      final data = Uint8List.fromList(
        List<int>.generate(
          DataChannelChunkCodec.maxMessageBytes * 2,
          (index) => index % 256,
        ),
      );

      final packets = DataChannelChunkCodec.encode(
        fileHash: fileHash,
        chunkIndex: 42,
        data: data,
      );

      expect(packets.length, greaterThan(1));
      final fragments = packets.map(DataChannelChunkCodec.decode).toList();

      expect(fragments, everyElement(isA<DecodedChunkFragment>()));
      for (var i = 0; i < fragments.length; i++) {
        final fragment = fragments[i] as DecodedChunkFragment;
        expect(fragment.fileHash, fileHash);
        expect(fragment.chunkIndex, 42);
        expect(fragment.fragmentIndex, i);
        expect(fragment.fragmentCount, packets.length);
      }
    });

    test('returns null for undersized binary messages', () {
      expect(
        DataChannelChunkCodec.decode(Uint8List.fromList([1, 2, 3])),
        isNull,
      );
    });
  });
}
