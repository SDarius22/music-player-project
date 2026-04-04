import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:music_player_frontend/core/services/rest_clients/auth_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebRTCService {
  final String myDeviceId;
  final AuthService authService;
  final WebSocketChannel signalingSocket;
  final Function(String fileHash, int chunkIndex, Uint8List data)
  onChunkReceived;
  final Future<Uint8List?> Function(String fileHash, int chunkIndex)
  onChunkRequested;
  final VoidCallback? onSyncTrigger;

  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Map<String, RTCDataChannel> _dataChannels = {};
  final Map<String, List<RTCIceCandidate>> _iceQueues = {};
  final Map<String, Set<String>> _peerLibraries = {};

  // key: peerId, value: list of pending requests (fileHash + chunkIndex)
  final Map<String, List<({String fileHash, int chunkIndex})>>
  _pendingChunkRequests = {};

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
    this.onSyncTrigger,
  }) {
    _listenToSignaling();
  }

  bool get isConnected => _dataChannels.isNotEmpty;

  bool hasPeersForSong(String fileHash) {
    for (final peerSongs in _peerLibraries.values) {
      if (peerSongs.contains(fileHash)) {
        return true;
      }
    }
    return false;
  }

  void requestChunk(String fileHash, int chunkIndex) {
    final requestMsg = 'REQUEST_CHUNK:$fileHash:$chunkIndex';

    for (final entry in _dataChannels.entries) {
      final peerId = entry.key;
      final channel = entry.value;

      if (channel.state == RTCDataChannelState.RTCDataChannelOpen &&
          _peerLibraries[peerId]?.contains(fileHash) == true) {
        channel.send(RTCDataChannelMessage(requestMsg));
        return;
      }
    }

    for (final peerId in _peerLibraries.keys) {
      if (_peerLibraries[peerId]?.contains(fileHash) == true) {
        _pendingChunkRequests.putIfAbsent(peerId, () => []);
        _pendingChunkRequests[peerId]!.add((
          fileHash: fileHash,
          chunkIndex: chunkIndex,
        ));
        return;
      }
    }
  }

  void registerCache(String fileHash, List<int> chunkIndices) {
    if (!authService.isLoggedIn) return;
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

  void discoverPeers(String fileHash) {
    if (!authService.isLoggedIn) return;

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
        _handleBinaryMessage(message.binary);
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
      channel.send(
        RTCDataChannelMessage(
          'REQUEST_CHUNK:${req.fileHash}:${req.chunkIndex}',
        ),
      );
    }
  }

  void _handleBinaryMessage(Uint8List binary) {
    try {
      if (binary.length < 68) {
        debugPrint('[P2P] Binary message too short: ${binary.length} bytes');
        return;
      }

      final fileHash = String.fromCharCodes(binary.sublist(0, 64));
      final byteData = ByteData.sublistView(binary, 64, 68);
      final chunkIndex = byteData.getUint32(0, Endian.big);
      final audioData = binary.sublist(68);

      debugPrint(
        '[P2P] Received chunk from peer — song=$fileHash chunk=$chunkIndex (${audioData.length} bytes)',
      );
      onChunkReceived(fileHash, chunkIndex, audioData);
    } catch (e) {
      debugPrint("Error parsing binary P2P message: $e");
    }
  }

  Future<void> _handleTextMessage(String remotePeerId, String text) async {
    if (text.startsWith('REQUEST_CHUNK:')) {
      // Format: REQUEST_CHUNK:<fileHash>:<chunkIndex>
      // fileHash is 64 hex chars; chunkIndex is the last segment
      final lastColon = text.lastIndexOf(':');
      if (lastColon > 'REQUEST_CHUNK:'.length) {
        final fileHash = text.substring('REQUEST_CHUNK:'.length, lastColon);
        final chunkIndex = int.tryParse(text.substring(lastColon + 1));
        if (chunkIndex != null) {
          final data = await onChunkRequested(fileHash, chunkIndex);
          if (data != null) {
            _sendChunkToPeer(remotePeerId, fileHash, chunkIndex, data);
          }
        }
      }
    }
  }

  void _sendChunkToPeer(
    String targetPeerId,
    String fileHash,
    int chunkIndex,
    Uint8List data,
  ) {
    final channel = _dataChannels[targetPeerId];
    if (channel != null &&
        channel.state == RTCDataChannelState.RTCDataChannelOpen) {
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
  }

  void dispose() {
    for (var element in _dataChannels.values) {
      element.close();
    }
    for (var element in _peerConnections.values) {
      element.close();
    }
    signalingSocket.sink.close();
  }
}
