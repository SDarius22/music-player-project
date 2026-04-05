import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:music_player_frontend/core/services/rest_clients/auth_service.dart';
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
      await pc.setLocalDescription(offer);

      _sendSignal(
        type: 'OFFER',
        targetId: remotePeerId,
        payload: {'sdp': offer.sdp, 'type': offer.type},
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
      final type = signal['type'];
      final senderId = signal['senderId'];
      final payload = signal['payload'];

      if (senderId == myDeviceId) return;

      switch (type) {
        case 'SYNC_TRIGGER':
          onSyncTrigger?.call();
          break;

        case 'PEER_BUFFER_MAP':
          final discoveredFileHash = signal['fileHash'] as String;
          final Map<String, dynamic> map = payload;
          for (final peerId in map.keys) {
            _peerLibraries.putIfAbsent(peerId, () => {});
            _peerLibraries[peerId]!.add(discoveredFileHash);

            if (!_peerConnections.containsKey(peerId)) {
              _createPeerConnection(peerId, true);
            }
          }
          break;

        case 'OFFER':
          await _createPeerConnection(senderId, false);
          final pc = _peerConnections[senderId];
          if (pc != null) {
            await pc.setRemoteDescription(
              RTCSessionDescription(payload['sdp'], payload['type']),
            );

            _drainIceQueue(senderId, pc);

            final answer = await pc.createAnswer();
            await pc.setLocalDescription(answer);
            _sendSignal(
              type: 'ANSWER',
              targetId: senderId,
              payload: {'sdp': answer.sdp, 'type': answer.type},
            );
          }
          break;

        case 'ANSWER':
          final pc = _peerConnections[senderId];
          if (pc != null) {
            await pc.setRemoteDescription(
              RTCSessionDescription(payload['sdp'], payload['type']),
            );
            _drainIceQueue(senderId, pc);
          }
          break;

        case 'ICE_CANDIDATE':
          final pc = _peerConnections[senderId];
          final candidate = RTCIceCandidate(
            payload['candidate'],
            payload['sdpMid'],
            payload['sdpMLineIndex'],
          );

          if (pc != null && (await pc.getRemoteDescription() != null)) {
            await pc.addCandidate(candidate);
          } else {
            _iceQueues[senderId]?.add(candidate);
          }
          break;
      }
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
