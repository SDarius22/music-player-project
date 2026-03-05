import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebRTCService {
  final String myDeviceId;
  final WebSocketChannel signalingSocket;
  final Function(int chunkIndex, Uint8List data) onChunkReceived;
  final Future<Uint8List?> Function(int songId, int chunkIndex)
  onChunkRequested;

  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;

  bool get isConnected =>
      _dataChannel?.state == RTCDataChannelState.RTCDataChannelOpen;

  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ],
  };

  WebRTCService({
    required this.myDeviceId,
    required this.signalingSocket,
    required this.onChunkReceived,
    required this.onChunkRequested,
  }) {
    _listenToSignaling();
  }

  Future<void> _initializePeerConnection(String targetPeerId) async {
    _peerConnection = await createPeerConnection(_iceServers);

    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate != null) {
        _sendSignal(
          type: 'ICE_CANDIDATE',
          targetId: targetPeerId,
          payload: {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
        );
      }
    };

    // 2. Listen for the remote peer opening a DataChannel
    _peerConnection!.onDataChannel = (RTCDataChannel channel) {
      _dataChannel = channel;
      _bindDataChannelListeners();
    };
  }

  /// Binds listeners to process incoming binary chunks or string commands
  void _bindDataChannelListeners() {
    _dataChannel?.onMessage = (RTCDataChannelMessage message) async {
      if (message.isBinary) {
        // THE FIX: Read the first 4 bytes to extract the exact chunkIndex
        final byteData = ByteData.sublistView(message.binary);
        final int chunkIndex = byteData.getUint32(0, Endian.big);
        final Uint8List actualAudioData = message.binary.sublist(4);

        debugPrint(
          "Received P2P binary payload for Chunk $chunkIndex (${actualAudioData.length} bytes)",
        );
        onChunkReceived(chunkIndex, actualAudioData);
      } else {
        final text = message.text;
        debugPrint("Received P2P command: $text");

        // THE FIX: Parse the request and send the binary data back!
        if (text.startsWith('REQUEST_CHUNK:')) {
          final parts = text.split(':');
          if (parts.length == 3) {
            final songId = int.parse(parts[1]);
            final chunkIndex = int.parse(parts[2]);

            // Ask the local disk for the file
            final chunkData = await onChunkRequested(songId, chunkIndex);

            if (chunkData != null) {
              sendChunkToPeer(chunkIndex, chunkData);
            } else {
              debugPrint(
                "Peer asked for Chunk $chunkIndex but we don't have it cached!",
              );
            }
          }
        }
      }
    };
  }

  /// PEER A: Requests a chunk over the open P2P channel (Updated with Song ID)
  void requestChunk(int songId, int chunkIndex) {
    if (_dataChannel?.state == RTCDataChannelState.RTCDataChannelOpen) {
      _dataChannel!.send(
        RTCDataChannelMessage('REQUEST_CHUNK:$songId:$chunkIndex'),
      );
    }
  }

  /// PEER B: Frames the binary data with the chunkIndex and blasts it over UDP
  void sendChunkToPeer(int chunkIndex, Uint8List chunkData) {
    if (_dataChannel?.state == RTCDataChannelState.RTCDataChannelOpen) {
      // Allocate 4 extra bytes for the integer header
      final ByteData header = ByteData(4 + chunkData.length);
      header.setUint32(0, chunkIndex, Endian.big); // Write the index

      // Copy the raw audio bytes directly after the 4-byte header
      final Uint8List framedPacket = header.buffer.asUint8List();
      framedPacket.setAll(4, chunkData);

      _dataChannel!.send(RTCDataChannelMessage.fromBinary(framedPacket));
    }
  }

  /// Helper to send JSON messages through your established Spring Boot WebSocket
  void _sendSignal({
    required String type,
    required String targetId,
    required Map<String, dynamic> payload,
  }) {
    final signal = {
      'type': type,
      'senderId': myDeviceId,
      'targetId': targetId,
      'songId': 1, // Dynamically set this in production
      'payload': payload,
    };
    signalingSocket.sink.add(jsonEncode(signal));
  }

  /// PEER A (The Leecher): Initiates the connection to request chunks
  Future<void> initiateCall(String targetPeerId) async {
    await _initializePeerConnection(targetPeerId);

    // The caller MUST create the DataChannel before creating the offer
    RTCDataChannelInit dataChannelDict = RTCDataChannelInit()..ordered = true;
    _dataChannel = await _peerConnection!.createDataChannel(
      'chunk_transfer',
      dataChannelDict,
    );
    _bindDataChannelListeners();

    // Create the SDP Offer
    RTCSessionDescription offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    // Send the Offer through Spring Boot
    _sendSignal(
      type: 'OFFER',
      targetId: targetPeerId,
      payload: {'sdp': offer.sdp, 'type': offer.type},
    );
  }

  /// Master WebSocket Listener: Routes incoming signals from Spring Boot
  void _listenToSignaling() {
    signalingSocket.stream.listen((message) async {
      final signal = jsonDecode(message);
      final type = signal['type'];
      final senderId = signal['senderId'];
      final payload = signal['payload'];

      switch (type) {
        case 'PEER_BUFFER_MAP': // <-- ADD THIS CASE
          _handlePeerBufferMap(payload);
          break;
        case 'OFFER':
          await _handleReceiveOffer(senderId, payload);
          break;
        case 'ANSWER':
          await _handleReceiveAnswer(payload);
          break;
        case 'ICE_CANDIDATE':
          await _handleReceiveIceCandidate(payload);
          break;
      }
    });
  }

  /// Parses the active swarm and initiates the direct connection to the seeder
  void _handlePeerBufferMap(Map<String, dynamic> payload) {
    if (payload.isEmpty) {
      debugPrint(
        "Swarm is empty. Proceeding with Master Server HTTP fallback.",
      );
      return;
    }

    // For your thesis prototype, we aggressively grab the very first peer in the swarm.
    // In a production environment, you would run an algorithm to find the peer with the most chunks.
    String targetPeerId = payload.keys.first;
    debugPrint(
      "Discovered peer in swarm: $targetPeerId. Initiating WebRTC Handshake...",
    );

    initiateCall(targetPeerId);
  }

  /// PEER B (The Seeder): Receives the Offer and generates an Answer
  Future<void> _handleReceiveOffer(
    String remotePeerId,
    Map<String, dynamic> payload,
  ) async {
    await _initializePeerConnection(remotePeerId);

    // Apply the remote peer's SDP
    RTCSessionDescription remoteDesc = RTCSessionDescription(
      payload['sdp'],
      payload['type'],
    );
    await _peerConnection!.setRemoteDescription(remoteDesc);

    // Generate the SDP Answer
    RTCSessionDescription answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    // Send the Answer back through Spring Boot
    _sendSignal(
      type: 'ANSWER',
      targetId: remotePeerId,
      payload: {'sdp': answer.sdp, 'type': answer.type},
    );
  }

  /// PEER A: Receives the Answer and finalizes the connection
  Future<void> _handleReceiveAnswer(Map<String, dynamic> payload) async {
    RTCSessionDescription remoteDesc = RTCSessionDescription(
      payload['sdp'],
      payload['type'],
    );
    await _peerConnection!.setRemoteDescription(remoteDesc);
  }

  /// BOTH PEERS: Adds discovered network routes to punch through the NAT
  Future<void> _handleReceiveIceCandidate(Map<String, dynamic> payload) async {
    RTCIceCandidate candidate = RTCIceCandidate(
      payload['candidate'],
      payload['sdpMid'],
      payload['sdpMLineIndex'],
    );
    await _peerConnection?.addCandidate(candidate);
  }

  /// Tells the backend: "I just downloaded these chunks, add me to the registry."
  void registerCache(int songId, List<int> chunkIndices) {
    signalingSocket.sink.add(
      jsonEncode({
        'type': 'REGISTER_CACHE',
        'senderId': myDeviceId,
        'targetId': 'SERVER',
        'songId': songId,
        'payload': chunkIndices,
      }),
    );
  }

  /// Asks the backend: "Who currently has the chunks for this song?"
  void discoverPeers(int songId) {
    signalingSocket.sink.add(
      jsonEncode({
        'type': 'DISCOVER_PEERS',
        'senderId': myDeviceId,
        'targetId': 'SERVER',
        'songId': songId,
        'payload': {},
      }),
    );
  }
}
