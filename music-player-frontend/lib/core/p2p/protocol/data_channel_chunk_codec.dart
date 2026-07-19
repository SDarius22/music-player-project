import 'dart:typed_data';

sealed class DecodedChunkMessage {
  const DecodedChunkMessage({required this.fileHash, required this.chunkIndex});

  final String fileHash;
  final int chunkIndex;
}

final class DecodedChunkPacket extends DecodedChunkMessage {
  const DecodedChunkPacket({
    required super.fileHash,
    required super.chunkIndex,
    required this.data,
  });

  final Uint8List data;
}

final class DecodedChunkFragment extends DecodedChunkMessage {
  const DecodedChunkFragment({
    required super.fileHash,
    required super.chunkIndex,
    required this.fragmentIndex,
    required this.fragmentCount,
    required this.payload,
  });

  final int fragmentIndex;
  final int fragmentCount;
  final Uint8List payload;
}

final class DataChannelChunkCodec {
  const DataChannelChunkCodec._();

  static const int legacyHeaderBytes = 68;
  static const int fragmentHeaderBytes = 77;
  static const int maxMessageBytes = 16 * 1024;
  static const List<int> _fragmentMagic = [80, 50, 80, 70]; // P2PF
  static const int _fragmentVersion = 1;

  static List<Uint8List> encode({
    required String fileHash,
    required int chunkIndex,
    required Uint8List data,
  }) {
    final hashBytes = Uint8List.fromList(fileHash.codeUnits);

    if (legacyHeaderBytes + data.length <= maxMessageBytes) {
      return [_encodeLegacy(hashBytes, chunkIndex, data)];
    }

    final maxPayloadBytes = maxMessageBytes - fragmentHeaderBytes;
    final fragmentCount = (data.length / maxPayloadBytes).ceil();
    if (fragmentCount > 65535) return const [];

    return [
      for (
        var fragmentIndex = 0;
        fragmentIndex < fragmentCount;
        fragmentIndex++
      )
        _encodeFragment(
          hashBytes: hashBytes,
          chunkIndex: chunkIndex,
          fragmentIndex: fragmentIndex,
          fragmentCount: fragmentCount,
          data: data,
          maxPayloadBytes: maxPayloadBytes,
        ),
    ];
  }

  static DecodedChunkMessage? decode(Uint8List binary) {
    if (_isFragment(binary)) {
      return _decodeFragment(binary);
    }
    if (binary.length >= legacyHeaderBytes) {
      return _decodeLegacy(binary);
    }
    return null;
  }

  static Uint8List _encodeLegacy(
    Uint8List hashBytes,
    int chunkIndex,
    Uint8List data,
  ) {
    final packet = Uint8List(legacyHeaderBytes + data.length);
    packet.setAll(0, hashBytes);
    ByteData.sublistView(packet, 64, 68).setUint32(0, chunkIndex, Endian.big);
    packet.setAll(legacyHeaderBytes, data);
    return packet;
  }

  static Uint8List _encodeFragment({
    required Uint8List hashBytes,
    required int chunkIndex,
    required int fragmentIndex,
    required int fragmentCount,
    required Uint8List data,
    required int maxPayloadBytes,
  }) {
    final start = fragmentIndex * maxPayloadBytes;
    final slice = data.sublist(
      start,
      (start + maxPayloadBytes).clamp(0, data.length),
    );
    final packet = Uint8List(fragmentHeaderBytes + slice.length);

    packet.setAll(0, _fragmentMagic);
    packet[4] = _fragmentVersion;
    packet.setAll(5, hashBytes);
    ByteData.sublistView(packet, 69, 73).setUint32(0, chunkIndex, Endian.big);
    ByteData.sublistView(
      packet,
      73,
      75,
    ).setUint16(0, fragmentIndex, Endian.big);
    ByteData.sublistView(
      packet,
      75,
      77,
    ).setUint16(0, fragmentCount, Endian.big);
    packet.setAll(fragmentHeaderBytes, slice);
    return packet;
  }

  static DecodedChunkPacket _decodeLegacy(Uint8List binary) {
    final fileHash = String.fromCharCodes(binary.sublist(0, 64));
    final chunkIndex = ByteData.sublistView(
      binary,
      64,
      68,
    ).getUint32(0, Endian.big);
    return DecodedChunkPacket(
      fileHash: fileHash,
      chunkIndex: chunkIndex,
      data: binary.sublist(legacyHeaderBytes),
    );
  }

  static DecodedChunkFragment _decodeFragment(Uint8List binary) {
    final fileHash = String.fromCharCodes(binary.sublist(5, 69));
    final chunkIndex = ByteData.sublistView(
      binary,
      69,
      73,
    ).getUint32(0, Endian.big);
    final fragmentIndex = ByteData.sublistView(
      binary,
      73,
      75,
    ).getUint16(0, Endian.big);
    final fragmentCount = ByteData.sublistView(
      binary,
      75,
      77,
    ).getUint16(0, Endian.big);
    return DecodedChunkFragment(
      fileHash: fileHash,
      chunkIndex: chunkIndex,
      fragmentIndex: fragmentIndex,
      fragmentCount: fragmentCount,
      payload: binary.sublist(fragmentHeaderBytes),
    );
  }

  static bool _isFragment(Uint8List binary) =>
      binary.length >= fragmentHeaderBytes &&
      binary[0] == _fragmentMagic[0] &&
      binary[1] == _fragmentMagic[1] &&
      binary[2] == _fragmentMagic[2] &&
      binary[3] == _fragmentMagic[3] &&
      binary[4] == _fragmentVersion;
}
