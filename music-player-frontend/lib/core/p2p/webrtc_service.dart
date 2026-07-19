// coverage:ignore-file

import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:logging/logging.dart';
import 'package:music_player_frontend/core/rest_clients/auth_service.dart';
import 'package:music_player_frontend/core/services/settings_service.dart';
import 'package:music_player_frontend/core/p2p/protocol/chunk_assembly.dart';
import 'package:music_player_frontend/core/p2p/protocol/data_channel_chunk_codec.dart';
import 'package:music_player_frontend/core/p2p/protocol/peer_stats.dart';
import 'package:music_player_frontend/core/p2p/protocol/sdp_summary.dart';
import 'package:music_player_frontend/core/p2p/protocol/signaling_payload_parser.dart';
import 'package:universal_platform/universal_platform.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebRTCService {
  static final _logger = Logger('WebRTCService');

  final String myDeviceId;
  final AuthService authService;
  final WebSocketChannel Function() _connectSignaling;
  WebSocketChannel? _signalingSocket;
  final SettingsService? settingsService;
  final void Function(String fileHash, int chunkIndex, Uint8List data)
  onChunkReceived;
  final Future<Uint8List?> Function(String fileHash, int chunkIndex)
  onChunkRequested;

  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Map<String, RTCDataChannel> _dataChannels = {};
  final Map<String, List<RTCIceCandidate>> _iceQueues = {};
  final Map<String, Map<String, Set<int>>> _peerLibraries = {};
  final Map<String, List<({String fileHash, int chunkIndex})>>
  _pendingChunkRequests = {};
  final Map<String, PeerStats> _peerStats = {};
  final Map<String, ({String peerId, DateTime sentAt})>
  _outstandingChunkRequests = {};

  final Map<String, DateTime> _pcSetupStartedAt = {};

  final Set<String> _awaitingAnswer = {};
  final Map<String, String> _pendingOfferId = {};
  int _offerSeq = 0;

  final Map<String, ChunkAssembly> _assemblies = {};

  Timer? _keepaliveTimer;
  bool _disposed = false;
  final ValueNotifier<int> peerStateVersionNotifier = ValueNotifier<int>(0);

  static const Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ],
  };

  SdpSummary _summarizeSdp(String type, String sdp) =>
      SdpSummary.fromSdp(type: type, sdp: sdp);

  String _candidateType(String candidate) {
    final match = RegExp(r'typ\s+([a-zA-Z0-9_-]+)').firstMatch(candidate);
    return match?.group(1) ?? 'unknown';
  }

  String _summarizeIceCandidate(RTCIceCandidate candidate) {
    final raw = candidate.candidate ?? '';
    return 'mid=${candidate.sdpMid ?? '-'} '
        'mLine=${candidate.sdpMLineIndex ?? -1} '
        'type=${_candidateType(raw)} len=${raw.length} candidate=$raw';
  }

  String _summarizePayload(String type, dynamic payload) {
    switch (type) {
      case 'OFFER':
      case 'ANSWER':
        final parsed = parseSdpPayload(payload);
        if (parsed == null) return 'invalid-sdp';
        return '${_summarizeSdp(parsed.type, parsed.sdp)} offerId=${parsed.offerId ?? '-'}';
      case 'ICE_CANDIDATE':
        final candidate = _parseIceCandidate(payload);
        if (candidate == null) return 'invalid-ice';
        return _summarizeIceCandidate(candidate);
      case 'PEER_BUFFER_MAP':
        final map = normalizePayload(payload);
        return 'peers=${map?.keys.join(',') ?? '-'}';
      default:
        if (payload is Map || payload is List) return jsonEncode(payload);
        return '$payload';
    }
  }

  WebRTCService({
    required this.myDeviceId,
    required this.authService,
    required WebSocketChannel Function() connectSignaling,
    required this.onChunkReceived,
    required this.onChunkRequested,
    this.settingsService,
  }) : _connectSignaling = connectSignaling {
    _maybeConnect();
    authService.addListener(_maybeConnect);
  }

  void _maybeConnect() {
    if (_signalingSocket != null) return;
    if (authService.accessToken == null) return;
    _connect();
  }

  void _connect() {
    _signalingSocket = _connectSignaling();
    _listenToSignaling();
    _sendAuth();
    _startKeepalive();
  }

  void _sendAuth() {
    final token = authService.accessToken;
    if (token == null) return;
    _sendToSignaling({'type': 'AUTH', 'token': token, 'senderId': myDeviceId});
  }

  bool get isConnected => _dataChannels.isNotEmpty;

  void _notifyPeerStateChanged() {
    peerStateVersionNotifier.value++;
  }

  List<String> getSortedPeersForSong(String fileHash) {
    final peers =
        _peerLibraries.entries
            .where((e) => e.value[fileHash]?.isNotEmpty ?? false)
            .map((e) => e.key)
            .toList();
    return _sortPeersByScore(peers);
  }

  List<String> getSortedPeersForChunk(String fileHash, int chunkIndex) {
    final peers =
        _peerLibraries.entries
            .where((e) => e.value[fileHash]?.contains(chunkIndex) ?? false)
            .map((e) => e.key)
            .toList();
    return _sortPeersByScore(peers);
  }

  List<String> _sortPeersByScore(List<String> peers) {
    peers.sort(
      (a, b) =>
          (_peerStats[b]?.score ?? 0).compareTo(_peerStats[a]?.score ?? 0),
    );
    return peers;
  }

  void requestChunkFromPeer(String peerId, String fileHash, int chunkIndex) {
    final channel = _dataChannels[peerId];
    if (channel?.state == RTCDataChannelState.RTCDataChannelOpen) {
      final key = '$peerId:$fileHash:$chunkIndex';
      _outstandingChunkRequests[key] = (peerId: peerId, sentAt: DateTime.now());
      _logger.fine(
        'Requesting chunk idx=$chunkIndex file=$fileHash from peer=$peerId via open data channel',
      );
      channel!.send(
        RTCDataChannelMessage('REQUEST_CHUNK:$fileHash:$chunkIndex'),
      );
    } else {
      _logger.fine(
        'Queueing chunk idx=$chunkIndex file=$fileHash for peer=$peerId '
        '(channelState=${channel?.state ?? 'null'})',
      );
      _pendingChunkRequests.putIfAbsent(peerId, () => []).add((
        fileHash: fileHash,
        chunkIndex: chunkIndex,
      ));
    }
  }

  Future<void> registerCache(String fileHash, List<int> chunkIndices) async {
    final allowed = await _isP2PAllowed();
    if (!authService.isLoggedIn || !allowed) {
      _logger.fine(
        '[P2P] Skipping cache registration for $fileHash — not allowed',
      );
      return;
    }
    _sendToSignaling({
      'type': 'REGISTER_CACHE',
      'senderId': myDeviceId,
      'targetId': 'SERVER',
      'fileHash': fileHash,
      'payload': chunkIndices,
    });
  }

  Future<void> discoverPeers(String fileHash) async {
    final allowed = await _isP2PAllowed();
    if (!authService.isLoggedIn || !allowed) {
      return;
    }
    _sendToSignaling({
      'type': 'DISCOVER_PEERS',
      'senderId': myDeviceId,
      'targetId': 'SERVER',
      'fileHash': fileHash,
      'payload': {},
    });
  }

  void dispose() {
    _disposed = true;
    _keepaliveTimer?.cancel();
    authService.removeListener(_maybeConnect);
    for (final ch in _dataChannels.values) {
      ch.close();
    }
    for (final pc in _peerConnections.values) {
      pc.close();
    }
    _signalingSocket?.sink.close();
  }

  @visibleForTesting
  static Map<String, dynamic>? normalizePayload(dynamic payload) =>
      SignalingPayloadParser.normalizePayload(payload);

  @visibleForTesting
  static Map<String, Set<int>> normalizePeerBufferMap(dynamic payload) =>
      SignalingPayloadParser.normalizePeerBufferMap(payload);

  @visibleForTesting
  static String? nonEmptyString(dynamic value) =>
      SignalingPayloadParser.nonEmptyString(value);

  @visibleForTesting
  static ({String sdp, String type, String? offerId})? parseSdpPayload(
    dynamic payload,
  ) => SignalingPayloadParser.parseSdpPayload(payload);

  String _nextOfferId() =>
      '$myDeviceId-${DateTime.now().microsecondsSinceEpoch}-${_offerSeq++}';

  /// Sends a JSON message on the signaling socket, guarding against a closed or
  /// disposed socket (late async callbacks — e.g. a chunk cached during teardown
  /// calling registerCache — otherwise throw "Cannot add event after closing").
  void _sendToSignaling(Map<String, dynamic> message) {
    if (_disposed) return;
    final socket = _signalingSocket;
    if (socket == null) return;
    try {
      socket.sink.add(jsonEncode(message));
    } catch (e) {
      _logger.fine('[P2P] Dropped signaling message (socket closing): $e');
    }
  }

  void _sendSignal({
    required String type,
    required String targetId,
    required Map<String, dynamic> payload,
  }) {
    if (!authService.isLoggedIn) return;
    _logger.fine(
      'Sending $type to peer=$targetId ${_summarizePayload(type, payload)}',
    );
    _sendToSignaling({
      'type': type,
      'senderId': myDeviceId,
      'targetId': targetId,
      'payload': payload,
    });
  }

  Future<bool> _applyRemoteDescription(
    String peerId,
    RTCPeerConnection pc,
    ({String sdp, String type, String? offerId}) remote,
  ) async {
    try {
      _logger.fine(
        'Applying remote description from peer=$peerId '
        '${_summarizeSdp(remote.type, remote.sdp)} offerId=${remote.offerId ?? '-'}',
      );
      await pc.setRemoteDescription(
        RTCSessionDescription(remote.sdp, remote.type),
      );
      final current = await pc.getRemoteDescription();
      if (current?.sdp case final sdp? when current?.type != null) {
        _logger.fine(
          'Remote description set for peer=$peerId '
          '${_summarizeSdp(current!.type!, sdp)}',
        );
      }
      return true;
    } catch (e) {
      _logger.warning(
        '[P2P] setRemoteDescription failed from $peerId '
        '(type=${remote.type} offerId=${remote.offerId ?? '-'} len=${remote.sdp.length})',
        e,
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
    if (!_awaitingAnswer.contains(peerId) || expected == null) {
      _logger.fine(
        'Rejecting ANSWER from peer=$peerId because no matching pending offer exists '
        '(offerId=${answerOfferId ?? '-'})',
      );
      return true;
    }

    if (answerOfferId != null && answerOfferId != expected) {
      _logger.warning(
        '[P2P] ANSWER offerId mismatch from $peerId (expected=$expected got=$answerOfferId)',
      );
      return true;
    }
    if (answerOfferId == null) {
      _logger.fine(
        '[P2P] ANSWER from $peerId has no offerId — accepting (compat mode)',
      );
    }

    final local = await pc.getLocalDescription();
    final valid = local?.type?.toLowerCase() == 'offer';
    _logger.fine(
      'Evaluating ANSWER from peer=$peerId offerId=${answerOfferId ?? '-'} '
      'expected=$expected localType=${local?.type ?? '-'} valid=$valid',
    );
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
    if (_peerConnections.containsKey(remotePeerId)) {
      _logger.fine('Peer connection already exists for peer=$remotePeerId');
      return;
    }

    _iceQueues.putIfAbsent(remotePeerId, () => []);
    _pcSetupStartedAt[remotePeerId] = DateTime.now();
    final pc = await createPeerConnection(_iceServers);
    _peerConnections[remotePeerId] = pc;
    _logger.fine(
      'Created peer connection for peer=$remotePeerId initiator=$initiator',
    );

    pc.onSignalingState = (state) {
      _logger.fine('peer=$remotePeerId signalingState=$state');
    };

    pc.onIceGatheringState = (state) {
      _logger.fine('peer=$remotePeerId iceGatheringState=$state');
    };

    pc.onIceConnectionState = (state) {
      _logger.fine('peer=$remotePeerId iceConnectionState=$state');
    };

    pc.onIceCandidate = (c) {
      if (c.candidate == null) {
        _logger.fine(
          'peer=$remotePeerId local ICE gathering yielded null candidate (end-of-candidates)',
        );
        return;
      }
      _logger.fine(
        'peer=$remotePeerId local ICE candidate ${_summarizeIceCandidate(c)}',
      );
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
      _logger.fine('peer=$remotePeerId connectionState=$state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        _logger.fine(
          'Closing peer=$remotePeerId due to terminal-ish connection state=$state',
        );
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
        _logger.warning('[P2P] Skipping OFFER to $remotePeerId — empty SDP');
        return;
      }
      _logger.fine(
        'Created local OFFER for peer=$remotePeerId ${_summarizeSdp(type, sdp)}',
      );
      await pc.setLocalDescription(offer);
      final local = await pc.getLocalDescription();
      if (local?.sdp case final localSdp? when local?.type != null) {
        _logger.fine(
          'Local description set for peer=$remotePeerId '
          '${_summarizeSdp(local!.type!, localSdp)}',
        );
      }

      final offerId = _nextOfferId();
      _awaitingAnswer.add(remotePeerId);
      _pendingOfferId[remotePeerId] = offerId;

      _sendSignal(
        type: 'OFFER',
        targetId: remotePeerId,
        payload: {'sdp': sdp, 'type': type, 'offerId': offerId},
      );
    } else {
      pc.onDataChannel = (ch) {
        _logger.fine(
          'peer=$remotePeerId received remote data channel '
          'label=${ch.label} id=${ch.id} state=${ch.state}',
        );
        _setupDataChannel(remotePeerId, ch);
      };
    }
  }

  void _closePeer(String peerId) {
    _logger.fine(
      'Closing peer=$peerId dataChannel=${_dataChannels[peerId]?.state ?? 'null'} '
      'pcPresent=${_peerConnections.containsKey(peerId)} queuedIce=${_iceQueues[peerId]?.length ?? 0}',
    );
    _dataChannels[peerId]?.close();
    _peerConnections[peerId]?.close();
    _dataChannels.remove(peerId);
    _peerConnections.remove(peerId);
    _iceQueues.remove(peerId);
    _peerLibraries.remove(peerId);
    _pendingChunkRequests.remove(peerId);
    _awaitingAnswer.remove(peerId);
    _pendingOfferId.remove(peerId);
    _pcSetupStartedAt.remove(peerId);
    _notifyPeerStateChanged();

    _outstandingChunkRequests.removeWhere((_, v) {
      if (v.peerId == peerId) {
        _peerStats.putIfAbsent(peerId, PeerStats.new).recordFailure();
        return true;
      }
      return false;
    });
  }

  void _drainIceQueue(String peerId, RTCPeerConnection pc) {
    final queue = _iceQueues.remove(peerId) ?? [];
    _iceQueues[peerId] = [];
    _logger.fine(
      'Draining ${queue.length} queued ICE candidate(s) for peer=$peerId',
    );
    for (final c in queue) {
      pc
          .addCandidate(c)
          .then(
            (_) => _logger.fine(
              'peer=$peerId queued ICE candidate added ${_summarizeIceCandidate(c)}',
            ),
          )
          .catchError((e) => _logger.warning('[P2P] addCandidate error', e));
    }
  }

  void _setupDataChannel(String peerId, RTCDataChannel channel) {
    _dataChannels[peerId] = channel;
    _logger.fine(
      'Configuring data channel for peer=$peerId '
      'label=${channel.label} id=${channel.id} state=${channel.state}',
    );
    channel.onDataChannelState = (state) {
      _logger.fine('peer=$peerId dataChannelState=$state');
      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        _recordIceSetup(peerId);
        _drainPendingRequests(peerId, channel);
      }
    };
    if (channel.state == RTCDataChannelState.RTCDataChannelOpen) {
      _recordIceSetup(peerId);
      _drainPendingRequests(peerId, channel);
    }
    channel.onMessage = (msg) async {
      if (msg.isBinary) {
        _logger.fine(
          'peer=$peerId received binary message len=${msg.binary.length}',
        );
        _handleBinaryMessage(peerId, msg.binary);
      } else {
        _logger.fine('peer=$peerId received text message: ${msg.text}');
        await _handleTextMessage(peerId, msg.text);
      }
    };
  }

  void _recordIceSetup(String peerId) {
    final start = _pcSetupStartedAt.remove(peerId);
    if (start == null) return;
    final ms = DateTime.now().difference(start).inMicroseconds / 1000.0;
    _peerStats.putIfAbsent(peerId, PeerStats.new).setupMs = ms;
    _logger.info('[METRIC] ice_setup_ms=${ms.toStringAsFixed(1)} peer=$peerId');
  }

  void _drainPendingRequests(String peerId, RTCDataChannel channel) {
    final pending = _pendingChunkRequests.remove(peerId);
    if (pending == null || pending.isEmpty) return;
    _logger.fine(
      '[P2P] DataChannel open with $peerId — draining ${pending.length} queued request(s)',
    );
    for (final req in pending) {
      final key = '$peerId:${req.fileHash}:${req.chunkIndex}';
      _outstandingChunkRequests[key] = (peerId: peerId, sentAt: DateTime.now());
      _logger.fine(
        'Draining queued chunk request peer=$peerId file=${req.fileHash} idx=${req.chunkIndex}',
      );
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
      _logger.warning('[P2P] Chunk upload blocked by monthly data limit');
      return;
    }

    final packets = DataChannelChunkCodec.encode(
      fileHash: fileHash,
      chunkIndex: chunkIndex,
      data: data,
    );
    if (packets.isEmpty) return;

    _logger.fine(
      'Sending chunk peer=$peerId file=$fileHash idx=$chunkIndex bytes=${data.length} '
      'mode=${packets.length == 1 ? 'single' : 'fragmented'} fragments=${packets.length}',
    );

    for (final packet in packets) {
      await _awaitDrainableBuffer(channel!);
      if (channel.state != RTCDataChannelState.RTCDataChannelOpen) return;
      channel.send(RTCDataChannelMessage.fromBinary(packet));
    }
  }

  static const int _maxBufferedBytes = 1 << 20; // 1 MiB

  Future<void> _awaitDrainableBuffer(RTCDataChannel channel) async {
    var waitedMs = 0;
    while ((channel.bufferedAmount ?? 0) > _maxBufferedBytes) {
      if (channel.state != RTCDataChannelState.RTCDataChannelOpen) return;
      if (waitedMs >= 5000) {
        _logger.warning(
          '[P2P] data channel send buffer stuck above ${_maxBufferedBytes}B '
          'after ${waitedMs}ms; sending anyway',
        );
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
      waitedMs += 20;
    }
  }

  void _handleBinaryMessage(String peerId, Uint8List binary) {
    try {
      switch (DataChannelChunkCodec.decode(binary)) {
        case DecodedChunkFragment fragment:
          _assembleFragment(peerId, fragment);
        case DecodedChunkPacket packet:
          _deliverChunk(
            peerId,
            packet.fileHash,
            packet.chunkIndex,
            packet.data,
          );
        case null:
          _logger.warning(
            '[P2P] Binary message too short: ${binary.length} bytes',
          );
      }
    } catch (e) {
      _logger.warning('[P2P] Error parsing binary message', e);
    }
  }

  void _assembleFragment(String peerId, DecodedChunkFragment fragment) {
    if (fragment.fragmentCount == 0 ||
        fragment.fragmentIndex >= fragment.fragmentCount) {
      return;
    }

    final key = '$peerId:${fragment.fileHash}:${fragment.chunkIndex}';
    final assembly = _assemblies.putIfAbsent(
      key,
      () => ChunkAssembly(fragment.fragmentCount),
    );
    _logger.fine(
      'peer=$peerId fragment file=${fragment.fileHash} idx=${fragment.chunkIndex} '
      'part=${fragment.fragmentIndex + 1}/${fragment.fragmentCount} bytes=${fragment.payload.length}',
    );

    if (assembly.fragmentCount != fragment.fragmentCount) {
      _assemblies.remove(key);
      return;
    }
    assembly.addFragment(fragment.fragmentIndex, fragment.payload);
    if (!assembly.isComplete) return;

    final data = assembly.assemble();
    _assemblies.remove(key);
    if (data == null) return;
    _deliverChunk(peerId, fragment.fileHash, fragment.chunkIndex, data);
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
          .putIfAbsent(peerId, PeerStats.new)
          .recordDelivery(data.length, ms);
      _logger.fine(
        '[P2P] chunk from peer=$peerId song=$fileHash idx=$chunkIndex '
        '(${data.length}b ${ms.toStringAsFixed(1)}ms)',
      );
    } else {
      _logger.fine(
        'Received unsolicited chunk peer=$peerId file=$fileHash idx=$chunkIndex bytes=${data.length}',
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
        _peerStats.putIfAbsent(peerId, PeerStats.new).recordRtt(rtt.toDouble());
        _logger.fine(
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
      _sendToSignaling({'type': 'PING', 'senderId': myDeviceId});

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
        _logger.fine(
          'Marking request as stale key=$key peer=${v.peerId} ageMs=${DateTime.now().difference(v.sentAt).inMilliseconds}',
        );
        _peerStats.putIfAbsent(v.peerId, PeerStats.new).recordFailure();
        return true;
      }
      return false;
    });
  }

  void _listenToSignaling() {
    _signalingSocket!.stream.listen((message) async {
      final signal = jsonDecode(message);
      if (signal is! Map) return;
      final type = signal['type'];
      final senderId = nonEmptyString(signal['senderId']);
      final payload = signal['payload'];
      if (senderId == null || senderId == myDeviceId) return;
      _logger.fine(
        'Received $type from peer=$senderId ${_summarizePayload(type?.toString() ?? '-', payload)}',
      );

      switch (type) {
        case 'PEER_BUFFER_MAP':
          _handlePeerBufferMapSignal(signal, payload);

        case 'OFFER':
          await _handleOfferSignal(senderId, payload);

        case 'ANSWER':
          await _handleAnswerSignal(senderId, payload);

        case 'ICE_CANDIDATE':
          await _handleIceCandidateSignal(senderId, payload);
      }
    }, onError: (e) => _logger.warning('[P2P] signaling error', e));
  }

  void _handlePeerBufferMapSignal(
    Map<dynamic, dynamic> signal,
    dynamic payload,
  ) {
    final hash = nonEmptyString(signal['fileHash']);
    final map = normalizePeerBufferMap(payload);
    if (hash == null) {
      _logger.warning('[P2P] Ignoring malformed PEER_BUFFER_MAP');
      return;
    }
    _logger.fine(
      'Peer discovery for file=$hash returned peers=${map.keys.join(',')}',
    );
    for (final entry in map.entries) {
      final peerId = entry.key;
      _peerLibraries.putIfAbsent(peerId, () => {})[hash] = entry.value;
      if (!_peerConnections.containsKey(peerId)) {
        _createPeerConnection(peerId, true);
      }
    }
    _notifyPeerStateChanged();
  }

  Future<void> _handleOfferSignal(String senderId, dynamic payload) async {
    if (!_resolveOfferGlare(senderId)) return;

    await _createPeerConnection(senderId, false);
    final offerPc = _peerConnections[senderId];
    if (offerPc == null) return;

    final offerRemote = parseSdpPayload(payload);
    if (offerRemote == null) {
      _logger.warning('[P2P] Ignoring malformed OFFER from $senderId');
      return;
    }
    if (!await _applyRemoteDescription(senderId, offerPc, offerRemote)) {
      return;
    }
    _drainIceQueue(senderId, offerPc);

    await _createAndSendAnswer(senderId, offerPc, offerRemote.offerId);
  }

  bool _resolveOfferGlare(String senderId) {
    if (!_awaitingAnswer.contains(senderId)) return true;

    if (myDeviceId.compareTo(senderId) > 0) {
      _logger.warning('[P2P] Glare with $senderId — keeping local offer');
      return false;
    }
    _logger.warning('[P2P] Glare with $senderId — dropping local offer');
    _awaitingAnswer.remove(senderId);
    _pendingOfferId.remove(senderId);
    _closePeer(senderId);
    return true;
  }

  Future<void> _createAndSendAnswer(
    String senderId,
    RTCPeerConnection offerPc,
    String? offerId,
  ) async {
    final answer = await offerPc.createAnswer();
    final answerSdp = nonEmptyString(answer.sdp);
    final answerType = nonEmptyString(answer.type);
    if (answerSdp == null || answerType == null) {
      _logger.warning('[P2P] Skipping ANSWER to $senderId — empty SDP');
      return;
    }
    _logger.fine(
      'Created local ANSWER for peer=$senderId ${_summarizeSdp(answerType, answerSdp)}',
    );
    await offerPc.setLocalDescription(answer);
    final local = await offerPc.getLocalDescription();
    if (local?.sdp case final localSdp? when local?.type != null) {
      _logger.fine(
        'Local description set for peer=$senderId '
        '${_summarizeSdp(local!.type!, localSdp)}',
      );
    }
    _sendSignal(
      type: 'ANSWER',
      targetId: senderId,
      payload: {
        'sdp': answerSdp,
        'type': answerType,
        if (offerId != null) 'offerId': offerId,
      },
    );
  }

  Future<void> _handleAnswerSignal(String senderId, dynamic payload) async {
    final answerPc = _peerConnections[senderId];
    if (answerPc == null) return;

    final answerRemote = parseSdpPayload(payload);
    if (answerRemote == null) {
      _logger.warning('[P2P] Ignoring malformed ANSWER from $senderId');
      return;
    }
    if (await _shouldRejectAnswer(senderId, answerPc, answerRemote.offerId)) {
      _logger.warning('[P2P] Ignoring stale/unexpected ANSWER from $senderId');
      return;
    }
    if (!await _applyRemoteDescription(senderId, answerPc, answerRemote)) {
      return;
    }
    _drainIceQueue(senderId, answerPc);
  }

  Future<void> _handleIceCandidateSignal(
    String senderId,
    dynamic payload,
  ) async {
    final icePc = _peerConnections[senderId];
    final candidate = _parseIceCandidate(payload);
    if (candidate == null) {
      _logger.fine(
        'Ignoring malformed ICE_CANDIDATE from peer=$senderId payload=$payload',
      );
      return;
    }
    _logger.fine(
      'Received remote ICE candidate from peer=$senderId ${_summarizeIceCandidate(candidate)}',
    );
    if (icePc != null && await icePc.getRemoteDescription() != null) {
      await icePc.addCandidate(candidate);
      _logger.fine('Added remote ICE candidate immediately for peer=$senderId');
      return;
    }

    final queue = _iceQueues.putIfAbsent(senderId, () => []);
    queue.add(candidate);
    _logger.fine(
      'Queued remote ICE candidate for peer=$senderId pending remote description',
    );
  }

  Future<bool> _isP2PAllowed() async {
    if (UniversalPlatform.isDesktopOrWeb) return true;
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
    if (UniversalPlatform.isDesktopOrWeb) return true;
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
