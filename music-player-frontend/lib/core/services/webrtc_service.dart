import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebRTCService {
  final String myDeviceId;
  final WebSocketChannel signalingSocket;
  final Function(int chunkIndex, Uint8List data) onChunkReceived;

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
    _dataChannel?.onMessage = (RTCDataChannelMessage message) {
      if (message.isBinary) {
        // In a real implementation, you'd prefix the binary payload with the chunkIndex (e.g., first 4 bytes)
        // For this example, we assume the manager tracks the requested index.
        print("Received binary chunk of size: ${message.binary.length} bytes");
        // Pass it up to your StreamAudioSource
        onChunkReceived(-1, message.binary);
      } else {
        // Handle string commands (e.g., Peer A asking Peer B for Chunk 5)
        print("Received text command: ${message.text}");
      }
    };
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
      final senderId = signal['senderId']; // This is the remote peer's ID
      final payload = signal['payload'];

      switch (type) {
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

  /// PEER A: Requests a chunk over the open P2P channel
  void requestChunk(int chunkIndex) {
    if (_dataChannel?.state == RTCDataChannelState.RTCDataChannelOpen) {
      // Send a text command asking for the chunk
      _dataChannel!.send(RTCDataChannelMessage('REQUEST_CHUNK:$chunkIndex'));
    } else {
      print("DataChannel is not open yet!");
      // Fallback to your Spring Boot HTTP endpoint here if needed immediately
    }
  }

  /// PEER B: Reads from local disk and sends binary data
  void sendChunkToPeer(Uint8List chunkData) {
    if (_dataChannel?.state == RTCDataChannelState.RTCDataChannelOpen) {
      // Blast the raw bytes over the UDP channel
      _dataChannel!.send(RTCDataChannelMessage.fromBinary(chunkData));
    }
  }
}
