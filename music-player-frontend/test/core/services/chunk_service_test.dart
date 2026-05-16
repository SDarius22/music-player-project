import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:music_player_frontend/core/dtos/chunk_manifest_dto.dart';
import 'package:music_player_frontend/core/repository/interfaces/chunk_cache_repository.dart';
import 'package:music_player_frontend/core/rest_clients/streaming_rest_client.dart';
import 'package:music_player_frontend/core/services/chunk_service.dart';
import 'package:music_player_frontend/core/services/webrtc_service.dart';

import 'chunk_service_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<ChunkCacheRepository>(),
  MockSpec<StreamingRestClient>(),
  MockSpec<WebRTCService>(),
])
void main() {
  late MockChunkCacheRepository mockCacheRepo;
  late MockStreamingRestClient mockStreamingClient;
  late MockWebRTCService mockWebRtc;

  ChunkManifestDto buildManifest({int totalChunks = 10, List<String>? hashes}) {
    return ChunkManifestDto.fromJson({
      'fileHash': 'song-hash',
      'totalChunks': totalChunks,
      'chunkSize': 4,
      'totalBytes': totalChunks * 4,
      'hashes': hashes ?? List<String>.filled(totalChunks, ''),
    });
  }

  String hashOf(List<int> bytes) => sha256.convert(bytes).toString();

  setUp(() {
    mockCacheRepo = MockChunkCacheRepository();
    mockStreamingClient = MockStreamingRestClient();
    mockWebRtc = MockWebRTCService();

    when(mockWebRtc.discoverPeers(any)).thenAnswer((_) async {});
    when(mockWebRtc.registerCache(any, any)).thenAnswer((_) async {});
    when(mockWebRtc.getSortedPeersForSong(any)).thenReturn(const []);
    when(mockWebRtc.getSortedPeersForChunk(any, any)).thenReturn(const []);
    when(mockWebRtc.requestChunkFromPeer(any, any, any)).thenReturn(null);

    when(
      mockCacheRepo.getAvailableChunkIndices(any),
    ).thenAnswer((_) async => const []);
    when(mockCacheRepo.readChunk(any, any)).thenAnswer((_) async => null);
    when(mockCacheRepo.saveChunk(any, any, any)).thenAnswer((_) async {});
  });

  test('loadManifest fetches manifest and announces cached indices', () async {
    when(
      mockStreamingClient.fetchManifest('song-hash'),
    ).thenAnswer((_) async => buildManifest(totalChunks: 2));
    when(
      mockCacheRepo.getAvailableChunkIndices('song-hash'),
    ).thenAnswer((_) async => [0, 1]);

    final service = ChunkService(
      fileHash: 'song-hash',
      cacheRepo: mockCacheRepo,
      streamingClient: mockStreamingClient,
      webrtcManager: mockWebRtc,
    );

    await service.loadManifest();

    expect(service.isReady, isTrue);
    verify(mockWebRtc.discoverPeers('song-hash')).called(1);
    verify(mockWebRtc.registerCache('song-hash', [0, 1])).called(1);
  });

  test('getChunk returns local cached chunk without server request', () async {
    final cached = Uint8List.fromList([1, 2, 3]);
    final hashes = List<String>.filled(2, hashOf(cached));

    when(
      mockStreamingClient.fetchManifest('song-hash'),
    ).thenAnswer((_) async => buildManifest(totalChunks: 2, hashes: hashes));
    when(
      mockCacheRepo.readChunk('song-hash', 0),
    ).thenAnswer((_) async => cached);

    final service = ChunkService(
      fileHash: 'song-hash',
      cacheRepo: mockCacheRepo,
      streamingClient: mockStreamingClient,
      webrtcManager: mockWebRtc,
    );

    final result = await service.getChunk(0);

    expect(result, equals(cached));
    expect(service.wasServedByP2P(0), isFalse);
    verifyNever(mockStreamingClient.downloadChunkFallback(any, any));
  });

  test('getChunk fetches prefix chunks from server and caches them', () async {
    final serverData = Uint8List.fromList([9, 9, 9]);
    final hashes = [hashOf(serverData), hashOf(serverData), hashOf(serverData)];

    when(
      mockStreamingClient.fetchManifest('song-hash'),
    ).thenAnswer((_) async => buildManifest(totalChunks: 3, hashes: hashes));
    when(
      mockStreamingClient.downloadChunkFallback('song-hash', 0),
    ).thenAnswer((_) async => serverData);

    final service = ChunkService(
      fileHash: 'song-hash',
      cacheRepo: mockCacheRepo,
      streamingClient: mockStreamingClient,
      webrtcManager: mockWebRtc,
    );

    final result = await service.getChunk(0);

    expect(result, equals(serverData));
    verify(mockStreamingClient.downloadChunkFallback('song-hash', 0)).called(1);
    verify(mockCacheRepo.saveChunk('song-hash', 0, serverData)).called(1);
  });

  test('getChunk uses peer-delivered chunk when integrity passes', () async {
    final peerData = Uint8List.fromList([1, 4, 7, 9]);
    final hashes = List<String>.filled(3, hashOf(Uint8List.fromList([0])));
    hashes[2] = hashOf(peerData);

    when(
      mockStreamingClient.fetchManifest('song-hash'),
    ).thenAnswer((_) async => buildManifest(totalChunks: 3, hashes: hashes));
    when(
      mockWebRtc.getSortedPeersForChunk('song-hash', 2),
    ).thenReturn(const ['peer-1']);

    final service = ChunkService(
      fileHash: 'song-hash',
      cacheRepo: mockCacheRepo,
      streamingClient: mockStreamingClient,
      webrtcManager: mockWebRtc,
    );

    final pending = service.getChunk(2);
    await Future<void>.delayed(Duration.zero);
    service.resolvePeerRequest(2, peerData);
    final result = await pending;

    expect(result, equals(peerData));
    expect(service.wasServedByP2P(2), isTrue);
    verify(mockWebRtc.requestChunkFromPeer('peer-1', 'song-hash', 2)).called(1);
    verifyNever(mockStreamingClient.downloadChunkFallback('song-hash', 2));
  });

  test(
    'getChunk falls back to server when peer chunk fails integrity',
    () async {
      final peerData = Uint8List.fromList([1, 1, 1]);
      final serverData = Uint8List.fromList([2, 2, 2]);
      final hashes = List<String>.filled(12, hashOf(Uint8List.fromList([0])));
      hashes[8] = hashOf(serverData);

      when(
        mockStreamingClient.fetchManifest('song-hash'),
      ).thenAnswer((_) async => buildManifest(totalChunks: 12, hashes: hashes));
      when(
        mockWebRtc.getSortedPeersForChunk('song-hash', 8),
      ).thenReturn(const ['peer-1']);
      when(
        mockStreamingClient.downloadChunkFallback('song-hash', 8),
      ).thenAnswer((_) async => serverData);

      final service = ChunkService(
        fileHash: 'song-hash',
        cacheRepo: mockCacheRepo,
        streamingClient: mockStreamingClient,
        webrtcManager: mockWebRtc,
      );

      final pending = service.getChunk(8);
      await Future<void>.delayed(Duration.zero);
      service.resolvePeerRequest(8, peerData);
      final result = await pending;

      expect(result, equals(serverData));
      expect(service.wasServedByP2P(8), isFalse);
      verify(
        mockStreamingClient.downloadChunkFallback('song-hash', 8),
      ).called(1);
    },
  );

  test('prefetchChunk is no-op before manifest is loaded', () async {
    final service = ChunkService(
      fileHash: 'song-hash',
      cacheRepo: mockCacheRepo,
      streamingClient: mockStreamingClient,
      webrtcManager: mockWebRtc,
    );

    await service.prefetchChunk(0);

    verifyNever(mockStreamingClient.downloadChunkFallback(any, any));
  });

  test('prefetchChunk fetches and stores valid server chunk', () async {
    final data = Uint8List.fromList([5, 6, 7]);
    final hashes = List<String>.filled(5, hashOf(Uint8List.fromList([0])));
    hashes[3] = hashOf(data);

    when(
      mockStreamingClient.fetchManifest('song-hash'),
    ).thenAnswer((_) async => buildManifest(totalChunks: 5, hashes: hashes));
    when(
      mockStreamingClient.downloadChunkFallback('song-hash', 3),
    ).thenAnswer((_) async => data);

    final service = ChunkService(
      fileHash: 'song-hash',
      cacheRepo: mockCacheRepo,
      streamingClient: mockStreamingClient,
      webrtcManager: mockWebRtc,
    );

    await service.loadManifest();
    await service.prefetchChunk(3);

    verify(mockCacheRepo.saveChunk('song-hash', 3, data)).called(1);
  });
}
