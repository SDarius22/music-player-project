import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:music_player_frontend/core/rest_clients/auth_service.dart';
import 'package:music_player_frontend/core/services/settings_service.dart';
import 'package:universal_platform/universal_platform.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class _PeerStats {
  static const double _alpha = 0.2;

  double rttMs = 500.0;
  double throughputBytesPerMs = 0.001;
  int successes = 0;
  int failures = 0;

  double get successRate {
    final total = successes + failures;
    return total == 0 ? 0.5 : successes / total;
  }

  double get score => successRate * throughputBytesPerMs * 1000 / (rttMs + 1);

  void recordRtt(double ms) => rttMs = _alpha * ms + (1 - _alpha) * rttMs;

  void recordDelivery(int bytes, double elapsedMs) {
    successes++;
    final tput = bytes / elapsedMs.clamp(1, double.infinity);
    throughputBytesPerMs = _alpha * tput + (1 - _alpha) * throughputBytesPerMs;
  }

  void recordFailure() => failures++;
}

class _ChunkAssembly {
  final int fragmentCount;
  final Map<int, Uint8List> fragments = {};
  int totalBytes = 0;

  _ChunkAssembly(this.fragmentCount);
}

class WebRTCService {
  final String myDeviceId;
  final AuthService authService;
  final WebSocketChannel signalingSocket;
  final SettingsService? settingsService;
  final void Function(String fileHash, int chunkIndex, Uint8List data)
  onChunkReceived;
  final Future<Uint8List?> Function(String fileHash, int chunkIndex)
  onChunkRequested;
  final VoidCallback? onSyncTrigger;

  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Map<String, RTCDataChannel> _dataChannels = {};
  final Map<String, List<RTCIceCandidate>> _iceQueues = {};
  final Map<String, Set<String>> _peerLibraries = {};
  final Map<String, List<({String fileHash, int chunkIndex})>>
  _pendingChunkRequests = {};
  final Map<String, _PeerStats> _peerStats = {};
  final Map<String, ({String peerId, DateTime sentAt})>
  _outstandingChunkRequests = {};

  final Set<String> _awaitingAnswer = {};
  final Map<String, String> _pendingOfferId = {};
  int _offerSeq = 0;

  final Map<String, _ChunkAssembly> _assemblies = {};

  Timer? _keepaliveTimer;

  //    DataChannel binary protocol constants
  //    Legacy packet:   [hash:64][chunkIdx:4][data…]
  //    Fragment packet: [magic:4][ver:1][hash:64][chunkIdx:4][fragIdx:2][fragCount:2][data…]
  static const int _hdrBytes = 68; // legacy header size
  static const int _fragHdrBytes = 77; // fragment header size
  static const int _maxMsgBytes = 16 * 1024; // safe DataChannel send limit
  static const List<int> _magic = [80, 50, 80, 70]; // "P2PF"

  static const Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ],
  };

  WebRTCService({
    required this.myDeviceId,
    required this.authService,
    required this.signalingSocket,
    required this.onChunkReceived,
    required this.onChunkRequested,
    this.settingsService,
    this.onSyncTrigger,
  }) {
    _listenToSignaling();
    _startKeepalive();
  }

  bool get isConnected => _dataChannels.isNotEmpty;

  List<String> getSortedPeersForSong(String fileHash) {
    final peers =
        _peerLibraries.entries
            .where((e) => e.value.contains(fileHash))
            .map((e) => e.key)
            .toList()
          ..sort(
            (a, b) => (_peerStats[b]?.score ?? 0).compareTo(
              _peerStats[a]?.score ?? 0,
            ),
          );
    return peers;
  }

  void requestChunkFromPeer(String peerId, String fileHash, int chunkIndex) {
    final channel = _dataChannels[peerId];
    if (channel?.state == RTCDataChannelState.RTCDataChannelOpen) {
      final key = '$peerId:$fileHash:$chunkIndex';
      _outstandingChunkRequests[key] = (peerId: peerId, sentAt: DateTime.now());
      channel!.send(
        RTCDataChannelMessage('REQUEST_CHUNK:$fileHash:$chunkIndex'),
      );
    } else {
      _pendingChunkRequests.putIfAbsent(peerId, () => []).add((
        fileHash: fileHash,
        chunkIndex: chunkIndex,
      ));
    }
  }

  Future<void> registerCache(String fileHash, List<int> chunkIndices) async {
    final allowed = await _isP2PAllowed();
    if (!authService.isLoggedIn || !allowed) {
      debugPrint(
        '[P2P] Skipping cache registration for $fileHash — not allowed',
      );
      return;
    }
    signalingSocket.sink.add(
      jsonEncode({
        'type': 'REGISTER_CACHE',
        'senderId': myDeviceId,
        'targetId': 'SERVER',
        'fileHash': fileHash,
        'payload': chunkIndices,
        'userId': authService.userId,
      }),
    );
  }

  Future<void> discoverPeers(String fileHash) async {
    final allowed = await _isP2PAllowed();
    if (!authService.isLoggedIn || !allowed) {
      return;
    }
    signalingSocket.sink.add(
      jsonEncode({
        'type': 'DISCOVER_PEERS',
        'senderId': myDeviceId,
        'targetId': 'SERVER',
        'fileHash': fileHash,
        'payload': {},
        'userId': authService.userId,
      }),
    );
  }

  void dispose() {
    _keepaliveTimer?.cancel();
    for (final ch in _dataChannels.values) {
      ch.close();
    }
    for (final pc in _peerConnections.values) {
      pc.close();
    }
    signalingSocket.sink.close();
  }

  @visibleForTesting
  static Map<String, dynamic>? normalizePayload(dynamic payload) {
    if (payload is! Map) return null;
    return payload.map((k, v) => MapEntry(k.toString(), v));
  }

  @visibleForTesting
  static String? nonEmptyString(dynamic value) {
    if (value is! String) return null;
    final s = value.trim();
    return s.isEmpty ? null : s;
  }

  @visibleForTesting
  static ({String sdp, String type, String? offerId})? parseSdpPayload(
    dynamic payload,
  ) {
    final map = _asStringMap(payload);
    if (map == null) return null;

    final sdp = _canonicalizeSdp(map['sdp']);
    final type = nonEmptyString(map['type'])?.toLowerCase();
    if (sdp == null || type == null) return null;

    const valid = {'offer', 'answer', 'pranswer', 'rollback'};
    if (!valid.contains(type) || !sdp.startsWith('v=')) return null;

    return (sdp: sdp, type: type, offerId: nonEmptyString(map['offerId']));
  }

  static Map<String, dynamic>? _asStringMap(dynamic payload) {
    if (payload is Map) {
      return payload.map((k, v) => MapEntry(k.toString(), v));
    }
    final s = nonEmptyString(payload);
    if (s == null) return null;
    try {
      final decoded = jsonDecode(s);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
    } catch (_) {}
    return null;
  }

  static String? _canonicalizeSdp(dynamic value) {
    var sdp = nonEmptyString(value);
    if (sdp == null) return null;

    if (sdp.startsWith('"') && sdp.endsWith('"') && sdp.length >= 2) {
      sdp = sdp.substring(1, sdp.length - 1);
    }

    sdp =
        sdp
            .replaceAll(r'\r\n', '\n')
            .replaceAll(r'\n', '\n')
            .replaceAll('\r\n', '\n')
            .replaceAll('\r', '\n')
            .replaceAll('\u0000', '')
            .trim();

    if (sdp.isEmpty) return null;

    final lines =
        sdp
            .split('\n')
            .map((l) => l.trimRight())
            .where((l) => l.isNotEmpty)
            .toList();
    return lines.isEmpty ? null : '${lines.join('\r\n')}\r\n';
  }

  String _nextOfferId() =>
      '$myDeviceId-${DateTime.now().microsecondsSinceEpoch}-${_offerSeq++}';

  void _sendSignal({
    required String type,
    required String targetId,
    required Map<String, dynamic> payload,
  }) {
    if (!authService.isLoggedIn) return;
    signalingSocket.sink.add(
      jsonEncode({
        'type': type,
        'senderId': myDeviceId,
        'targetId': targetId,
        'payload': payload,
        'userId': authService.userId,
      }),
    );
  }

  Future<bool> _applyRemoteDescription(
    String peerId,
    RTCPeerConnection pc,
    ({String sdp, String type, String? offerId}) remote,
  ) async {
    try {
      await pc.setRemoteDescription(
        RTCSessionDescription(remote.sdp, remote.type),
      );
      return true;
    } catch (e) {
      debugPrint(
        '[P2P] setRemoteDescription failed from $peerId '
        '(type=${remote.type} offerId=${remote.offerId ?? '-'} len=${remote.sdp.length}): $e',
      );
      _closePeer(peerId);
      return false;
    }
  }

  Future<bool> _shouldRejectAnswer(
    String peerId,
    RTCPeerConnection pc,
    String? answerOfferId,
  ) async {
    final expected = _pendingOfferId[peerId];
    if (!_awaitingAnswer.contains(peerId) || expected == null) return true;

    if (answerOfferId != null && answerOfferId != expected) {
      debugPrint(
        '[P2P] ANSWER offerId mismatch from $peerId (expected=$expected got=$answerOfferId)',
      );
      return true;
    }
    if (answerOfferId == null) {
      debugPrint(
        '[P2P] ANSWER from $peerId has no offerId — accepting (compat mode)',
      );
    }

    final local = await pc.getLocalDescription();
    final valid = local?.type?.toLowerCase() == 'offer';
    _awaitingAnswer.remove(peerId);
    _pendingOfferId.remove(peerId);
    return !valid;
  }

  RTCIceCandidate? _parseIceCandidate(dynamic payload) {
    final map = normalizePayload(payload);
    if (map == null) return null;
    final candidate = nonEmptyString(map['candidate']);
    if (candidate == null) return null;
    final mLineRaw = map['sdpMLineIndex'];
    final sdpMLineIndex = switch (mLineRaw) {
      int v => v,
      String v => int.tryParse(v),
      _ => null,
    };
    return RTCIceCandidate(candidate, map['sdpMid'] as String?, sdpMLineIndex);
  }

  Future<void> _createPeerConnection(
    String remotePeerId,
    bool initiator,
  ) async {
    if (_peerConnections.containsKey(remotePeerId)) return;

    _iceQueues.putIfAbsent(remotePeerId, () => []);
    final pc = await createPeerConnection(_iceServers);
    _peerConnections[remotePeerId] = pc;

    pc.onIceCandidate = (c) {
      if (c.candidate == null) return;
      _sendSignal(
        type: 'ICE_CANDIDATE',
        targetId: remotePeerId,
        payload: {
          'candidate': c.candidate,
          'sdpMid': c.sdpMid,
          'sdpMLineIndex': c.sdpMLineIndex,
        },
      );
    };

    pc.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        _closePeer(remotePeerId);
      }
    };

    if (initiator) {
      final dc = await pc.createDataChannel(
        'chunk_transfer',
        RTCDataChannelInit()..ordered = true,
      );
      _setupDataChannel(remotePeerId, dc);

      final offer = await pc.createOffer();
      final sdp = nonEmptyString(offer.sdp);
      final type = nonEmptyString(offer.type);
      if (sdp == null || type == null) {
        debugPrint('[P2P] Skipping OFFER to $remotePeerId — empty SDP');
        return;
      }
      await pc.setLocalDescription(offer);

      final offerId = _nextOfferId();
      _awaitingAnswer.add(remotePeerId);
      _pendingOfferId[remotePeerId] = offerId;

      _sendSignal(
        type: 'OFFER',
        targetId: remotePeerId,
        payload: {'sdp': sdp, 'type': type, 'offerId': offerId},
      );
    } else {
      pc.onDataChannel = (ch) => _setupDataChannel(remotePeerId, ch);
    }
  }

  void _closePeer(String peerId) {
    _dataChannels[peerId]?.close();
    _peerConnections[peerId]?.close();
    _dataChannels.remove(peerId);
    _peerConnections.remove(peerId);
    _iceQueues.remove(peerId);
    _peerLibraries.remove(peerId);
    _pendingChunkRequests.remove(peerId);
    _awaitingAnswer.remove(peerId);
    _pendingOfferId.remove(peerId);

    _outstandingChunkRequests.removeWhere((_, v) {
      if (v.peerId == peerId) {
        _peerStats.putIfAbsent(peerId, _PeerStats.new).recordFailure();
        return true;
      }
      return false;
    });
  }

  void _drainIceQueue(String peerId, RTCPeerConnection pc) {
    final queue = _iceQueues.remove(peerId) ?? [];
    _iceQueues[peerId] = [];
    for (final c in queue) {
      pc
          .addCandidate(c)
          .catchError((e) => debugPrint('[P2P] addCandidate error: $e'));
    }
  }

  void _setupDataChannel(String peerId, RTCDataChannel channel) {
    _dataChannels[peerId] = channel;
    channel.onDataChannelState = (state) {
      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        _drainPendingRequests(peerId, channel);
      }
    };
    if (channel.state == RTCDataChannelState.RTCDataChannelOpen) {
      _drainPendingRequests(peerId, channel);
    }
    channel.onMessage = (msg) async {
      if (msg.isBinary) {
        _handleBinaryMessage(peerId, msg.binary);
      } else {
        await _handleTextMessage(peerId, msg.text);
      }
    };
  }

  void _drainPendingRequests(String peerId, RTCDataChannel channel) {
    final pending = _pendingChunkRequests.remove(peerId);
    if (pending == null || pending.isEmpty) return;
    debugPrint(
      '[P2P] DataChannel open with $peerId — draining ${pending.length} queued request(s)',
    );
    for (final req in pending) {
      final key = '$peerId:${req.fileHash}:${req.chunkIndex}';
      _outstandingChunkRequests[key] = (peerId: peerId, sentAt: DateTime.now());
      channel.send(
        RTCDataChannelMessage(
          'REQUEST_CHUNK:${req.fileHash}:${req.chunkIndex}',
        ),
      );
    }
  }

  Future<void> _sendChunkToPeer(
    String peerId,
    String fileHash,
    int chunkIndex,
    Uint8List data,
  ) async {
    final channel = _dataChannels[peerId];
    if (channel?.state != RTCDataChannelState.RTCDataChannelOpen) return;
    if (!await _checkAndRecordUpload(data.length)) {
      debugPrint('[P2P] Chunk upload blocked by monthly data limit');
      return;
    }

    final hashBytes = Uint8List.fromList(fileHash.codeUnits);

    if (_hdrBytes + data.length <= _maxMsgBytes) {
      final pkt = Uint8List(_hdrBytes + data.length);
      pkt.setAll(0, hashBytes);
      ByteData.sublistView(pkt, 64, 68).setUint32(0, chunkIndex, Endian.big);
      pkt.setAll(_hdrBytes, data);
      channel!.send(RTCDataChannelMessage.fromBinary(pkt));
      return;
    }

    final maxPayload = _maxMsgBytes - _fragHdrBytes;
    final count = (data.length / maxPayload).ceil();
    if (count > 65535) return;

    for (var i = 0; i < count; i++) {
      final start = i * maxPayload;
      final slice = data.sublist(
        start,
        (start + maxPayload).clamp(0, data.length),
      );
      final pkt = Uint8List(_fragHdrBytes + slice.length);

      pkt.setAll(0, _magic);
      pkt[4] = 1; // version
      pkt.setAll(5, hashBytes);
      ByteData.sublistView(pkt, 69, 73).setUint32(0, chunkIndex, Endian.big);
      ByteData.sublistView(pkt, 73, 75).setUint16(0, i, Endian.big);
      ByteData.sublistView(pkt, 75, 77).setUint16(0, count, Endian.big);
      pkt.setAll(_fragHdrBytes, slice);

      channel!.send(RTCDataChannelMessage.fromBinary(pkt));
    }
  }

  void _handleBinaryMessage(String peerId, Uint8List binary) {
    try {
      if (_isFragment(binary)) {
        _assembleFragment(peerId, binary);
      } else if (binary.length >= _hdrBytes) {
        final fileHash = String.fromCharCodes(binary.sublist(0, 64));
        final chunkIndex = ByteData.sublistView(
          binary,
          64,
          68,
        ).getUint32(0, Endian.big);
        _deliverChunk(peerId, fileHash, chunkIndex, binary.sublist(_hdrBytes));
      } else {
        debugPrint('[P2P] Binary message too short: ${binary.length} bytes');
      }
    } catch (e) {
      debugPrint('[P2P] Error parsing binary message: $e');
    }
  }

  bool _isFragment(Uint8List b) =>
      b.length >= _fragHdrBytes &&
      b[0] == _magic[0] &&
      b[1] == _magic[1] &&
      b[2] == _magic[2] &&
      b[3] == _magic[3] &&
      b[4] == 1;

  void _assembleFragment(String peerId, Uint8List binary) {
    final fileHash = String.fromCharCodes(binary.sublist(5, 69));
    final chunkIndex = ByteData.sublistView(
      binary,
      69,
      73,
    ).getUint32(0, Endian.big);
    final fragIndex = ByteData.sublistView(
      binary,
      73,
      75,
    ).getUint16(0, Endian.big);
    final fragCount = ByteData.sublistView(
      binary,
      75,
      77,
    ).getUint16(0, Endian.big);
    final payload = binary.sublist(_fragHdrBytes);

    if (fragCount == 0 || fragIndex >= fragCount) return;

    final key = '$peerId:$fileHash:$chunkIndex';
    final assembly = _assemblies.putIfAbsent(
      key,
      () => _ChunkAssembly(fragCount),
    );

    if (assembly.fragmentCount != fragCount) {
      _assemblies.remove(key);
      return;
    }
    if (!assembly.fragments.containsKey(fragIndex)) {
      assembly.fragments[fragIndex] = payload;
      assembly.totalBytes += payload.length;
    }
    if (assembly.fragments.length < fragCount) return;

    final data = Uint8List(assembly.totalBytes);
    var offset = 0;
    for (var i = 0; i < fragCount; i++) {
      final part = assembly.fragments[i];
      if (part == null) {
        _assemblies.remove(key);
        return;
      }
      data.setAll(offset, part);
      offset += part.length;
    }
    _assemblies.remove(key);
    _deliverChunk(peerId, fileHash, chunkIndex, data);
  }

  void _deliverChunk(
    String peerId,
    String fileHash,
    int chunkIndex,
    Uint8List data,
  ) {
    final key = '$peerId:$fileHash:$chunkIndex';
    final req = _outstandingChunkRequests.remove(key);
    if (req != null) {
      final ms = DateTime.now().difference(req.sentAt).inMicroseconds / 1000.0;
      _peerStats
          .putIfAbsent(peerId, _PeerStats.new)
          .recordDelivery(data.length, ms);
      debugPrint(
        '[P2P] chunk from peer=$peerId song=$fileHash idx=$chunkIndex '
        '(${data.length}b ${ms.toStringAsFixed(1)}ms)',
      );
    }
    onChunkReceived(fileHash, chunkIndex, data);
  }

  Future<void> _handleTextMessage(String peerId, String text) async {
    if (text.startsWith('DC_PING:')) {
      final ts = text.substring('DC_PING:'.length);
      _dataChannels[peerId]?.send(RTCDataChannelMessage('DC_PONG:$ts'));
      return;
    }
    if (text.startsWith('DC_PONG:')) {
      final sent = int.tryParse(text.substring('DC_PONG:'.length));
      if (sent != null) {
        final rtt = DateTime.now().millisecondsSinceEpoch - sent;
        _peerStats
            .putIfAbsent(peerId, _PeerStats.new)
            .recordRtt(rtt.toDouble());
        debugPrint(
          '[P2P] RTT to $peerId: ${rtt}ms score=${_peerStats[peerId]!.score.toStringAsFixed(4)}',
        );
      }
      return;
    }
    if (text.startsWith('REQUEST_CHUNK:')) {
      final last = text.lastIndexOf(':');
      if (last <= 'REQUEST_CHUNK:'.length) return;
      final fileHash = text.substring('REQUEST_CHUNK:'.length, last);
      final idx = int.tryParse(text.substring(last + 1));
      if (idx == null) return;
      final data = await onChunkRequested(fileHash, idx);
      if (data != null) await _sendChunkToPeer(peerId, fileHash, idx, data);
    }
  }

  void _startKeepalive() {
    _keepaliveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      try {
        signalingSocket.sink.add(
          jsonEncode({
            'type': 'PING',
            'senderId': myDeviceId,
            'userId': authService.userId,
          }),
        );
      } catch (_) {}

      final now = DateTime.now().millisecondsSinceEpoch;
      for (final ch in _dataChannels.values) {
        if (ch.state == RTCDataChannelState.RTCDataChannelOpen) {
          try {
            ch.send(RTCDataChannelMessage('DC_PING:$now'));
          } catch (_) {}
        }
      }
      _cleanupStaleRequests();
    });
  }

  void _cleanupStaleRequests() {
    final cutoff = DateTime.now().subtract(const Duration(seconds: 2));
    _outstandingChunkRequests.removeWhere((key, v) {
      if (v.sentAt.isBefore(cutoff)) {
        _peerStats.putIfAbsent(v.peerId, _PeerStats.new).recordFailure();
        return true;
      }
      return false;
    });
  }

  void _listenToSignaling() {
    signalingSocket.stream.listen((message) async {
      final signal = jsonDecode(message);
      if (signal is! Map) return;
      final type = signal['type'];
      final senderId = nonEmptyString(signal['senderId']);
      final payload = signal['payload'];
      if (senderId == null || senderId == myDeviceId) return;

      switch (type) {
        case 'SYNC_TRIGGER':
          onSyncTrigger?.call();

        case 'PEER_BUFFER_MAP':
          final hash = nonEmptyString(signal['fileHash']);
          final map = normalizePayload(payload);
          if (hash == null || map == null) {
            debugPrint('[P2P] Ignoring malformed PEER_BUFFER_MAP');
            break;
          }
          for (final peerId in map.keys) {
            _peerLibraries.putIfAbsent(peerId, () => {}).add(hash);
            if (!_peerConnections.containsKey(peerId)) {
              _createPeerConnection(peerId, true);
            }
          }

        case 'OFFER':
          // Glare: both sides sent an offer simultaneously.
          // Resolve deterministically: higher deviceId keeps its offer.
          if (_awaitingAnswer.contains(senderId)) {
            if (myDeviceId.compareTo(senderId) > 0) {
              debugPrint('[P2P] Glare with $senderId — keeping local offer');
              break;
            }
            debugPrint('[P2P] Glare with $senderId — dropping local offer');
            _awaitingAnswer.remove(senderId);
            _pendingOfferId.remove(senderId);
            _closePeer(senderId);
          }

          await _createPeerConnection(senderId, false);
          final offerPc = _peerConnections[senderId];
          if (offerPc == null) break;

          final offerRemote = parseSdpPayload(payload);
          if (offerRemote == null) {
            debugPrint('[P2P] Ignoring malformed OFFER from $senderId');
            break;
          }
          if (!await _applyRemoteDescription(senderId, offerPc, offerRemote)) {
            break;
          }
          _drainIceQueue(senderId, offerPc);

          final answer = await offerPc.createAnswer();
          final answerSdp = nonEmptyString(answer.sdp);
          final answerType = nonEmptyString(answer.type);
          if (answerSdp == null || answerType == null) {
            debugPrint('[P2P] Skipping ANSWER to $senderId — empty SDP');
            break;
          }
          await offerPc.setLocalDescription(answer);
          _sendSignal(
            type: 'ANSWER',
            targetId: senderId,
            payload: {
              'sdp': answerSdp,
              'type': answerType,
              if (offerRemote.offerId != null) 'offerId': offerRemote.offerId,
            },
          );

        case 'ANSWER':
          final answerPc = _peerConnections[senderId];
          if (answerPc == null) break;

          final answerRemote = parseSdpPayload(payload);
          if (answerRemote == null) {
            debugPrint('[P2P] Ignoring malformed ANSWER from $senderId');
            break;
          }
          if (await _shouldRejectAnswer(
            senderId,
            answerPc,
            answerRemote.offerId,
          )) {
            debugPrint('[P2P] Ignoring stale/unexpected ANSWER from $senderId');
            break;
          }
          if (!await _applyRemoteDescription(
            senderId,
            answerPc,
            answerRemote,
          )) {
            break;
          }
          _drainIceQueue(senderId, answerPc);

        case 'ICE_CANDIDATE':
          final icePc = _peerConnections[senderId];
          final candidate = _parseIceCandidate(payload);
          if (candidate == null) break;
          if (icePc != null && await icePc.getRemoteDescription() != null) {
            await icePc.addCandidate(candidate);
          } else {
            final queue = _iceQueues.putIfAbsent(senderId, () => []);
            queue.add(candidate);
          }
      }
    }, onError: (e) => debugPrint('[P2P] signaling error: $e'));
  }

  Future<bool> _isP2PAllowed() async {
    if (UniversalPlatform.isDesktop || kIsWeb) return true;
    final settings = settingsService?.getAppSettings();
    if (settings == null) return true;
    final mode = settings.peerNetworkMode; // 0=WiFi 1=Cellular 2=Both
    if (mode == 2) return true;
    final results = await Connectivity().checkConnectivity();
    if (mode == 0) {
      return results.contains(ConnectivityResult.wifi);
    }
    if (mode == 1) {
      return results.contains(ConnectivityResult.mobile);
    }
    return true;
  }

  Future<bool> _checkAndRecordUpload(int bytes) async {
    if (UniversalPlatform.isDesktop || kIsWeb) return true;
    final service = settingsService;
    if (service == null) return true;

    final settings = service.getAppSettings();
    final now = DateTime.now();
    final month = now.year * 100 + now.month;

    if (settings.peerUploadResetMonth != month) {
      settings.peerWifiUploadedBytesThisMonth = 0;
      settings.peerCellularUploadedBytesThisMonth = 0;
      settings.peerUploadResetMonth = month;
    }

    final results = await Connectivity().checkConnectivity();
    if (results.contains(ConnectivityResult.wifi)) {
      final limit = settings.peerWifiDataLimitGB * 1024 * 1024 * 1024;
      if (settings.peerWifiDataLimitGB != -1 &&
          settings.peerWifiUploadedBytesThisMonth + bytes > limit) {
        return false;
      }
      settings.peerWifiUploadedBytesThisMonth += bytes;
    } else if (results.contains(ConnectivityResult.mobile)) {
      final limit = settings.peerCellularDataLimitGB * 1024 * 1024 * 1024;
      if (settings.peerCellularDataLimitGB != -1 &&
          settings.peerCellularUploadedBytesThisMonth + bytes > limit) {
        return false;
      }
      settings.peerCellularUploadedBytesThisMonth += bytes;
    }

    service.updateAppSettings(settings);
    return true;
  }
}
