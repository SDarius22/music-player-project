package com.example.musicplayerbackend.components;

import com.example.musicplayerbackend.domain.WebRTCMessage;
import com.example.musicplayerbackend.service.PeerTrackingService;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.handler.TextWebSocketHandler;

import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

@Component
@RequiredArgsConstructor
public class SignalingHandler extends TextWebSocketHandler {

    private final ObjectMapper objectMapper;
    private final PeerTrackingService peerTrackingService;

    private final Map<String, WebSocketSession> activeSessions = new ConcurrentHashMap<>();

    private final Map<String, String> sessionIdToPeerId = new ConcurrentHashMap<>();

    @Override
    public void afterConnectionClosed(WebSocketSession session, CloseStatus status) {
        String peerId = sessionIdToPeerId.remove(session.getId());
        if (peerId != null) {
            activeSessions.remove(peerId);
            peerTrackingService.unregisterPeer(peerId);
        }
    }

    @Override
    protected void handleTextMessage(WebSocketSession session, TextMessage message) throws Exception {
        System.out.println("[SIGNALING] " + session.getId() + " sent: " + message.getPayload());
        WebRTCMessage signal = objectMapper.readValue(message.getPayload(), WebRTCMessage.class);

        if (signal.senderId() != null) {
            activeSessions.put(signal.senderId(), session);
            sessionIdToPeerId.put(session.getId(), signal.senderId());
        }

        switch (signal.type()) {
            case "REGISTER_CACHE" -> {
                Set<Integer> chunkIndices = objectMapper.convertValue(signal.payload(), new TypeReference<Set<Integer>>() {
                });
                peerTrackingService.registerPeerChunks(signal.songId(), signal.senderId(), chunkIndices);
            }

            case "DISCOVER_PEERS" -> sendBufferMaps(session, signal.songId(), signal.senderId());

            case "OFFER", "ANSWER", "ICE_CANDIDATE" -> routeToTarget(signal);

            default -> session.close(CloseStatus.BAD_DATA.withReason("Unknown signal type"));
        }
    }

    private void sendBufferMaps(WebSocketSession session, Integer songId, String requestingPeerId) throws Exception {
        Map<String, Set<Integer>> peerBufferMaps = new ConcurrentHashMap<>(
                peerTrackingService.getPeerBufferMapsForSong(songId)
        );

        peerBufferMaps.remove(requestingPeerId);

        WebRTCMessage response = new WebRTCMessage(
                "PEER_BUFFER_MAP",
                "SERVER",
                requestingPeerId,
                songId,
                peerBufferMaps
        );

        session.sendMessage(new TextMessage(objectMapper.writeValueAsString(response)));
    }

    private void routeToTarget(WebRTCMessage signal) throws Exception {
        WebSocketSession targetSession = activeSessions.get(signal.targetId());

        if (targetSession != null && targetSession.isOpen()) {
            targetSession.sendMessage(new TextMessage(objectMapper.writeValueAsString(signal)));
        }
    }
}