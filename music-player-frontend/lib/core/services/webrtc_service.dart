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

  void recordRtt(double ms) {
    rttMs = _alpha * ms + (1 - _alpha) * rttMs;
  }

  void recordDelivery(int bytes, double elapsedMs) {
    successes++;
    final tput = bytes / elapsedMs.clamp(1, double.infinity);
    throughputBytesPerMs = _alpha * tput + (1 - _alpha) * throughputBytesPerMs;
  }

  void recordFailure() => failures++;
}

class WebRTCService {
  final String myDeviceId;
  final AuthService authService;
  final WebSocketChannel signalingSocket;
  final SettingsService? settingsService;
  final Function(String fileHash, int chunkIndex, Uint8List data)
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

  // Tracks peers for which we sent an offer and are waiting for an answer.
  final Set<String> _awaitingAnswerFromPeers = {};

  Timer? _keepaliveTimer;

  final Map<String, dynamic> _iceServers = {
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

  @visibleForTesting
  static Map<String, dynamic>? normalizePayload(dynamic payload) {
    if (payload is! Map) return null;
    return payload.map((key, value) => MapEntry(key.toString(), value));
  }

  @visibleForTesting
  static String? nonEmptyString(dynamic value) {
    if (value is! String) return null;
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }

  @visibleForTesting
  static ({String sdp, String type})? parseSdpPayload(dynamic payload) {
    final map = _normalizeSignalMap(payload);
    if (map == null) return null;

    final sdp = _normalizeSdp(map['sdp']);
    final type = nonEmptyString(map['type'])?.toLowerCase();
    if (sdp == null || type == null) return null;

    const validTypes = {'offer', 'answer', 'pranswer', 'rollback'};
    if (!validTypes.contains(type)) return null;

    // Basic sanity check to avoid passing malformed SDP into native WebRTC.
    if (!sdp.startsWith('v=')) return null;

    return (sdp: sdp, type: type);
  }

  static Map<String, dynamic>? _normalizeSignalMap(dynamic payload) {
    if (payload is Map) {
      return payload.map((key, value) => MapEntry(key.toString(), value));
    }

    final payloadString = nonEmptyString(payload);
    if (payloadString == null) return null;

    try {
      final decoded = jsonDecode(payloadString);
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (_) {
      // Not a JSON object payload; treat as invalid for SDP parsing.
    }
    return null;
  }

  static String? _normalizeSdp(dynamic value) {
    var sdp = nonEmptyString(value);
    if (sdp == null) return null;

    // Some signaling paths may double-encode SDP as a quoted JSON string.
    if (sdp.length >= 2 && sdp.startsWith('"') && sdp.endsWith('"')) {
      sdp = sdp.substring(1, sdp.length - 1);
    }

    // Convert escaped line endings into real line endings before native parsing.
    sdp = sdp
        .replaceAll(r'\r\n', '\n')
        .replaceAll(r'\n', '\n')
        .trim();

    return sdp.isEmpty ? null : sdp;
  }

  Future<bool> _applyRemoteDescription(
    String peerId,
    RTCPeerConnection pc,
    ({String sdp, String type}) remote,
  ) async {
    try {
      await pc.setRemoteDescription(RTCSessionDescription(remote.sdp, remote.type));
      return true;
    } catch (e) {
      debugPrint(
        '[P2P] Failed setRemoteDescription from $peerId '
        '(type=${remote.type}, sdpLength=${remote.sdp.length}): $e',
      );
      _closePeer(peerId);
      return false;
    }
  }

  Future<bool> _isStaleOrUnexpectedAnswer(
    String senderId,
    RTCPeerConnection pc,
  ) async {
    if (!_awaitingAnswerFromPeers.remove(senderId)) return true;

    final local = await pc.getLocalDescription();
    return local == null || local.type?.toLowerCase() != 'offer';
  }

  RTCIceCandidate? _parseIceCandidate(dynamic payload) {
    final map = normalizePayload(payload);
    if (map == null) return null;

    final candidate = nonEmptyString(map['candidate']);
    if (candidate == null) return null;

    final sdpMid = map['sdpMid'] as String?;
    final mLineRaw = map['sdpMLineIndex'];
    final sdpMLineIndex = switch (mLineRaw) {
      int value => value,
      String value => int.tryParse(value),
      _ => null,
    };

    return RTCIceCandidate(candidate, sdpMid, sdpMLineIndex);
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
      } catch (_) {
        // Socket may have closed
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      for (final entry in _dataChannels.entries) {
        if (entry.value.state == RTCDataChannelState.RTCDataChannelOpen) {
          try {
            entry.value.send(RTCDataChannelMessage('DC_PING:$now'));
          } catch (_) {}
        }
      }

      _cleanupStaleRequests();
    });
  }

  void _cleanupStaleRequests() {
    final cutoff = DateTime.now().subtract(const Duration(seconds: 2));
    _outstandingChunkRequests.removeWhere((_, value) {
      if (value.sentAt.isBefore(cutoff)) {
        _peerStats.putIfAbsent(value.peerId, _PeerStats.new).recordFailure();
        return true;
      }
      return false;
    });
  }

  Future<bool> _isP2PAllowed() async {
    if (UniversalPlatform.isDesktop || kIsWeb) return true;

    final settings = settingsService?.getAppSettings();
    if (settings == null) return true;

    final mode = settings.peerNetworkMode; // 0=WiFi, 1=Cellular, 2=Both
    if (mode == 2) return true;

    final results = await Connectivity().checkConnectivity();
    final hasWifi = results.contains(ConnectivityResult.wifi);
    final hasMobile = results.contains(ConnectivityResult.mobile);

    if (mode == 0) return hasWifi;
    if (mode == 1) return hasMobile;
    return true;
  }

  bool get isConnected => _dataChannels.isNotEmpty;

  List<String> getSortedPeersForSong(String fileHash) {
    final peers =
        _peerLibraries.entries
            .where((e) => e.value.contains(fileHash))
            .map((e) => e.key)
            .toList();
    peers.sort((a, b) {
      final scoreA = _peerStats[a]?.score ?? 0;
      final scoreB = _peerStats[b]?.score ?? 0;
      return scoreB.compareTo(scoreA);
    });
    return peers;
  }

  void requestChunkFromPeer(String peerId, String fileHash, int chunkIndex) {
    final channel = _dataChannels[peerId];
    if (channel != null &&
        channel.state == RTCDataChannelState.RTCDataChannelOpen) {
      final key = '$peerId:$fileHash:$chunkIndex';
      _outstandingChunkRequests[key] = (peerId: peerId, sentAt: DateTime.now());
      channel.send(
        RTCDataChannelMessage('REQUEST_CHUNK:$fileHash:$chunkIndex'),
      );
    } else {
      _pendingChunkRequests.putIfAbsent(peerId, () => []);
      _pendingChunkRequests[peerId]!.add((
        fileHash: fileHash,
        chunkIndex: chunkIndex,
      ));
    }
  }

  Future<void> registerCache(String fileHash, List<int> chunkIndices) async {
    if (!authService.isLoggedIn) return;
    if (!await _isP2PAllowed()) {
      debugPrint('[P2P] registerCache blocked by network mode preference');
      return;
    }
    debugPrint(
      '[P2P] Registering cache with server — song=$fileHash chunks=${chunkIndices.length}',
    );
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
    if (!authService.isLoggedIn) return;
    if (!await _isP2PAllowed()) {
      debugPrint('[P2P] discoverPeers blocked by network mode preference');
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

  Future<void> _createPeerConnection(
    String remotePeerId,
    bool initiator,
  ) async {
    if (_peerConnections.containsKey(remotePeerId)) return;

    _iceQueues[remotePeerId] = [];

    final pc = await createPeerConnection(_iceServers);
    _peerConnections[remotePeerId] = pc;

    pc.onIceCandidate = (candidate) {
      if (candidate.candidate != null) {
        _sendSignal(
          type: 'ICE_CANDIDATE',
          targetId: remotePeerId,
          payload: {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
        );
      }
    };

    pc.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        _closePeer(remotePeerId);
      }
    };

    if (initiator) {
      final dcInit = RTCDataChannelInit()..ordered = true;
      final dc = await pc.createDataChannel('chunk_transfer', dcInit);
      _setupDataChannel(remotePeerId, dc);

      final offer = await pc.createOffer();
      final offerSdp = nonEmptyString(offer.sdp);
      final offerType = nonEmptyString(offer.type);
      if (offerSdp == null || offerType == null) {
        debugPrint('[P2P] Skipping OFFER to $remotePeerId due to empty local SDP');
        return;
      }
      await pc.setLocalDescription(offer);
      _awaitingAnswerFromPeers.add(remotePeerId);

      _sendSignal(
        type: 'OFFER',
        targetId: remotePeerId,
        payload: {'sdp': offerSdp, 'type': offerType},
      );
    } else {
      pc.onDataChannel = (channel) {
        _setupDataChannel(remotePeerId, channel);
      };
    }
  }

  void _setupDataChannel(String remotePeerId, RTCDataChannel channel) {
    _dataChannels[remotePeerId] = channel;

    channel.onDataChannelState = (state) {
      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        _drainPendingRequests(remotePeerId, channel);
      }
    };

    if (channel.state == RTCDataChannelState.RTCDataChannelOpen) {
      _drainPendingRequests(remotePeerId, channel);
    }

    channel.onMessage = (message) async {
      if (message.isBinary) {
        _handleBinaryMessage(remotePeerId, message.binary);
      } else {
        await _handleTextMessage(remotePeerId, message.text);
      }
    };
  }

  void _drainPendingRequests(String peerId, RTCDataChannel channel) {
    final pending = _pendingChunkRequests.remove(peerId);
    if (pending == null) return;
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

  void _handleBinaryMessage(String peerId, Uint8List binary) {
    try {
      if (binary.length < 68) {
        debugPrint('[P2P] Binary message too short: ${binary.length} bytes');
        return;
      }

      final fileHash = String.fromCharCodes(binary.sublist(0, 64));
      final byteData = ByteData.sublistView(binary, 64, 68);
      final chunkIndex = byteData.getUint32(0, Endian.big);
      final audioData = binary.sublist(68);

      final key = '$peerId:$fileHash:$chunkIndex';
      final outstanding = _outstandingChunkRequests.remove(key);
      if (outstanding != null) {
        final elapsedMs =
            DateTime.now().difference(outstanding.sentAt).inMicroseconds /
            1000.0;
        _peerStats
            .putIfAbsent(peerId, _PeerStats.new)
            .recordDelivery(audioData.length, elapsedMs);
        debugPrint(
          '[P2P] Received chunk from peer=$peerId — song=$fileHash chunk=$chunkIndex '
          '(${audioData.length} bytes, ${elapsedMs.toStringAsFixed(1)} ms)',
        );
      }

      onChunkReceived(fileHash, chunkIndex, audioData);
    } catch (e) {
      debugPrint("Error parsing binary P2P message: $e");
    }
  }

  Future<void> _handleTextMessage(String remotePeerId, String text) async {
    if (text.startsWith('DC_PING:')) {
      final ts = text.substring('DC_PING:'.length);
      try {
        _dataChannels[remotePeerId]?.send(RTCDataChannelMessage('DC_PONG:$ts'));
      } catch (_) {}
    } else if (text.startsWith('DC_PONG:')) {
      final sentMs = int.tryParse(text.substring('DC_PONG:'.length));
      if (sentMs != null) {
        final rtt = DateTime.now().millisecondsSinceEpoch - sentMs;
        _peerStats
            .putIfAbsent(remotePeerId, _PeerStats.new)
            .recordRtt(rtt.toDouble());
        debugPrint(
          '[P2P] RTT to peer=$remotePeerId: ${rtt}ms '
          '(score=${_peerStats[remotePeerId]!.score.toStringAsFixed(4)})',
        );
      }
    } else if (text.startsWith('REQUEST_CHUNK:')) {
      final lastColon = text.lastIndexOf(':');
      if (lastColon > 'REQUEST_CHUNK:'.length) {
        final fileHash = text.substring('REQUEST_CHUNK:'.length, lastColon);
        final chunkIndex = int.tryParse(text.substring(lastColon + 1));
        if (chunkIndex != null) {
          final data = await onChunkRequested(fileHash, chunkIndex);
          if (data != null) {
            await _sendChunkToPeer(remotePeerId, fileHash, chunkIndex, data);
          }
        }
      }
    }
  }

  Future<void> _sendChunkToPeer(
    String targetPeerId,
    String fileHash,
    int chunkIndex,
    Uint8List data,
  ) async {
    final channel = _dataChannels[targetPeerId];
    if (channel == null ||
        channel.state != RTCDataChannelState.RTCDataChannelOpen) {
      return;
    }

    if (!await _checkAndRecordUpload(data.length)) {
      debugPrint('[P2P] Chunk upload blocked, monthly data limit reached');
      return;
    }

    // Header: 64-byte ASCII fileHash + 4-byte uint32 chunkIndex
    final hashBytes = Uint8List.fromList(fileHash.codeUnits);
    final header = ByteData(4);
    header.setUint32(0, chunkIndex, Endian.big);

    final packet = Uint8List(68 + data.length);
    packet.setAll(0, hashBytes);
    packet.setAll(64, header.buffer.asUint8List());
    packet.setAll(68, data);

    channel.send(RTCDataChannelMessage.fromBinary(packet));
  }

  Future<bool> _checkAndRecordUpload(int bytes) async {
    if (UniversalPlatform.isDesktop || kIsWeb) return true;

    final service = settingsService;
    if (service == null) return true;

    final settings = service.getAppSettings();

    final now = DateTime.now();
    final currentMonth = now.year * 100 + now.month;
    if (settings.peerUploadResetMonth != currentMonth) {
      settings.peerWifiUploadedBytesThisMonth = 0;
      settings.peerCellularUploadedBytesThisMonth = 0;
      settings.peerUploadResetMonth = currentMonth;
    }

    final results = await Connectivity().checkConnectivity();
    final isWifi = results.contains(ConnectivityResult.wifi);
    final isMobile = results.contains(ConnectivityResult.mobile);

    if (isWifi) {
      final limitBytes = settings.peerWifiDataLimitGB * 1024 * 1024 * 1024;
      if (settings.peerWifiDataLimitGB != -1 &&
          settings.peerWifiUploadedBytesThisMonth + bytes > limitBytes) {
        return false;
      }
      settings.peerWifiUploadedBytesThisMonth += bytes;
    } else if (isMobile) {
      final limitBytes = settings.peerCellularDataLimitGB * 1024 * 1024 * 1024;
      if (settings.peerCellularDataLimitGB != -1 &&
          settings.peerCellularUploadedBytesThisMonth + bytes > limitBytes) {
        return false;
      }
      settings.peerCellularUploadedBytesThisMonth += bytes;
    }

    service.updateAppSettings(settings);
    return true;
  }

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
          break;

        case 'PEER_BUFFER_MAP':
          final discoveredFileHash = nonEmptyString(signal['fileHash']);
          final map = normalizePayload(payload);
          if (discoveredFileHash == null || map == null) {
            debugPrint('[P2P] Ignoring malformed PEER_BUFFER_MAP signal');
            break;
          }
          for (final peerId in map.keys) {
            _peerLibraries.putIfAbsent(peerId, () => {});
            _peerLibraries[peerId]!.add(discoveredFileHash);

            if (!_peerConnections.containsKey(peerId)) {
              _createPeerConnection(peerId, true);
            }
          }
          break;

        case 'OFFER':
          if (_awaitingAnswerFromPeers.contains(senderId)) {
            // Simple glare handling: deterministically pick one offer to keep.
            final keepLocalOffer = myDeviceId.compareTo(senderId) > 0;
            if (keepLocalOffer) {
              debugPrint(
                '[P2P] Ignoring OFFER from $senderId due to glare (keeping local offer)',
              );
              break;
            }
            debugPrint(
              '[P2P] Glare detected with $senderId, dropping local offer and accepting remote OFFER',
            );
            _awaitingAnswerFromPeers.remove(senderId);
            _closePeer(senderId);
          }

          await _createPeerConnection(senderId, false);
          final pc = _peerConnections[senderId];
          if (pc != null) {
            final remote = parseSdpPayload(payload);
            if (remote == null) {
              debugPrint('[P2P] Ignoring malformed OFFER from $senderId');
              break;
            }
            final applied = await _applyRemoteDescription(senderId, pc, remote);
            if (!applied) break;

            _drainIceQueue(senderId, pc);

            final answer = await pc.createAnswer();
            final answerSdp = nonEmptyString(answer.sdp);
            final answerType = nonEmptyString(answer.type);
            if (answerSdp == null || answerType == null) {
              debugPrint('[P2P] Skipping ANSWER to $senderId due to empty local SDP');
              break;
            }
            await pc.setLocalDescription(answer);
            _sendSignal(
              type: 'ANSWER',
              targetId: senderId,
              payload: {'sdp': answerSdp, 'type': answerType},
            );
          }
          break;

        case 'ANSWER':
          final pc = _peerConnections[senderId];
          if (pc != null) {
            if (await _isStaleOrUnexpectedAnswer(senderId, pc)) {
              debugPrint('[P2P] Ignoring stale/unexpected ANSWER from $senderId');
              break;
            }

            final remote = parseSdpPayload(payload);
            if (remote == null) {
              debugPrint('[P2P] Ignoring malformed ANSWER from $senderId');
              break;
            }
            final applied = await _applyRemoteDescription(senderId, pc, remote);
            if (!applied) break;
            _drainIceQueue(senderId, pc);
          }
          break;

        case 'ICE_CANDIDATE':
          final pc = _peerConnections[senderId];
          final candidate = _parseIceCandidate(payload);
          if (candidate == null) break;

          if (pc != null && (await pc.getRemoteDescription() != null)) {
            await pc.addCandidate(candidate);
          } else {
            _iceQueues[senderId]?.add(candidate);
          }
          break;
      }
    }, onError: (error) {
      debugPrint('[P2P] signaling stream error: $error');
    });
  }

  void _drainIceQueue(String peerId, RTCPeerConnection pc) {
    final queue = _iceQueues[peerId];
    if (queue != null) {
      for (final candidate in queue) {
        pc.addCandidate(candidate).catchError((e) {
          debugPrint("Error adding queued ICE candidate: $e");
        });
      }
      queue.clear();
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
    _awaitingAnswerFromPeers.remove(peerId);

    // Mark any in-flight requests to this peer as failures.
    _outstandingChunkRequests.removeWhere((_, value) {
      if (value.peerId == peerId) {
        _peerStats.putIfAbsent(peerId, _PeerStats.new).recordFailure();
        return true;
      }
      return false;
    });
  }

  void dispose() {
    _keepaliveTimer?.cancel();
    for (var element in _dataChannels.values) {
      element.close();
    }
    for (var element in _peerConnections.values) {
      element.close();
    }
    signalingSocket.sink.close();
  }
}
