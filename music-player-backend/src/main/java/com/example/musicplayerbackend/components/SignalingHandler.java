package com.example.musicplayerbackend.components;

import com.example.musicplayerbackend.dto.WebRTCMessage;
import com.example.musicplayerbackend.service.PeerTrackingService;
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

    // Tracks active WebSocket connections by their session ID
    private final Map<String, WebSocketSession> activeSessions = new ConcurrentHashMap<>();

    @Override
    public void afterConnectionEstablished(WebSocketSession session) {
        activeSessions.put(session.getId(), session);
    }

    @Override
    public void afterConnectionClosed(WebSocketSession session, CloseStatus status) {
        activeSessions.remove(session.getId());
        peerTrackingService.unregisterPeer(session.getId());
    }

    @Override
    protected void handleTextMessage(WebSocketSession session, TextMessage message) throws Exception {
        WebRTCMessage signal = objectMapper.readValue(message.getPayload(), WebRTCMessage.class);

        // Java 25 enhanced switch expression
        switch (signal.type()) {
            case "REGISTER_CACHE" -> peerTrackingService.registerPeerCache(signal.songId(), session.getId());

            case "DISCOVER_PEERS" -> sendAvailablePeers(session, signal.songId());

            case "OFFER", "ANSWER", "ICE_CANDIDATE" -> routeToTarget(signal);

            default -> session.close(CloseStatus.BAD_DATA.withReason("Unknown signal type"));
        }
    }

    private void sendAvailablePeers(WebSocketSession session, Integer songId) throws Exception {
        Set<String> peers = peerTrackingService.getAvailablePeersForSong(songId);

        // Remove the requesting peer's own ID from the list if they are in it
        peers.remove(session.getId());

        WebRTCMessage response = new WebRTCMessage(
                "PEER_LIST",
                "SERVER",
                session.getId(),
                songId,
                peers
        );

        session.sendMessage(new TextMessage(objectMapper.writeValueAsString(response)));
    }

    private void routeToTarget(WebRTCMessage signal) throws Exception {
        WebSocketSession targetSession = activeSessions.get(signal.targetId());

        if (targetSession != null && targetSession.isOpen()) {
            // Forward the exact message to the target peer
            targetSession.sendMessage(new TextMessage(objectMapper.writeValueAsString(signal)));
        }
    }
}