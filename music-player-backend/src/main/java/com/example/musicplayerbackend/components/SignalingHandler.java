package com.example.musicplayerbackend.components;

import com.example.musicplayerbackend.domain.ClientConnection;
import com.example.musicplayerbackend.domain.PlaybackStateDto;
import com.example.musicplayerbackend.domain.WebRTCMessage;
import com.example.musicplayerbackend.service.PeerTrackingService;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.handler.TextWebSocketHandler;

import java.io.IOException;
import java.util.Collections;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

@Slf4j
@Component
@RequiredArgsConstructor
public class SignalingHandler extends TextWebSocketHandler {

    private final ObjectMapper objectMapper;
    private final PeerTrackingService peerTrackingService;

    private final Map<String, ClientConnection> registry = new ConcurrentHashMap<>();
    private final Map<Long, Set<String>> userIndex = new ConcurrentHashMap<>();
    private final Map<String, String> peerIndex = new ConcurrentHashMap<>();

    public void sendPlaybackStateChanged(Long userId, PlaybackStateDto state) {
        Set<String> sessionIds = userIndex.getOrDefault(userId, Collections.emptySet());
        String payload;
        try {
            payload = objectMapper.writeValueAsString(Map.of(
                    "type", "PLAYBACK_STATE_CHANGED",
                    "senderId", "SERVER",
                    "payload", state
            ));
        } catch (IOException e) {
            log.error("[SIGNALING] Failed to serialize PLAYBACK_STATE_CHANGED: {}", e.getMessage());
            return;
        }
        log.info("[SIGNALING] Sending PLAYBACK_STATE_CHANGED to user {} ({} session(s))", userId, sessionIds.size());
        for (String sessionId : sessionIds) {
            ClientConnection client = registry.get(sessionId);
            if (client != null && client.session().isOpen()) {
                try {
                    client.session().sendMessage(new TextMessage(payload));
                } catch (IOException e) {
                    log.error("[SIGNALING] Failed to send PLAYBACK_STATE_CHANGED to session {}: {}", sessionId, e.getMessage());
                }
            }
        }
    }

    public void sendSyncTrigger(Long userId) {
        Set<String> sessionIds = userIndex.getOrDefault(userId, Collections.emptySet());

        String triggerMessage = """
                    {
                        "type": "SYNC_TRIGGER",
                        "senderId": "SERVER",
                        "targetId": "BROADCAST"
                    }
                """;

        log.info("[SIGNALING] Sending SYNC_TRIGGER to user {} ({} session(s))", userId, sessionIds.size());
        for (String sessionId : sessionIds) {
            ClientConnection client = registry.get(sessionId);
            if (client != null && client.session().isOpen()) {
                try {
                    client.session().sendMessage(new TextMessage(triggerMessage));
                } catch (IOException e) {
                    log.error("[SIGNALING] Failed to send SYNC_TRIGGER to session {} (user {}): {}", sessionId, userId, e.getMessage());
                }
            }
        }
    }

    @Override
    public void afterConnectionEstablished(WebSocketSession session) {
        log.info("[SIGNALING] New WebSocket connection: session={}", session.getId());
    }

    @Override
    public void afterConnectionClosed(WebSocketSession session, CloseStatus status) {
        ClientConnection client = registry.remove(session.getId());

        if (client != null) {
            if (client.userId() != null) {
                Set<String> userSessions = userIndex.get(client.userId());
                if (userSessions != null) {
                    userSessions.remove(session.getId());
                    if (userSessions.isEmpty()) {
                        userIndex.remove(client.userId());
                    }
                }
            }

            if (client.peerId() != null) {
                peerIndex.remove(client.peerId());
                peerTrackingService.unregisterPeer(client.peerId());
                log.info("[SIGNALING] Peer disconnected: peerId={}, userId={}, status={}", client.peerId(), client.userId(), status);
            }
        }
    }

    @Override
    protected void handleTextMessage(WebSocketSession session, TextMessage message) throws Exception {
        Map<String, Object> payloadMap = objectMapper.readValue(message.getPayload(), new TypeReference<>() {
        });

        String type = (String) payloadMap.get("type");
        String senderId = (String) payloadMap.get("senderId");

        Long userId = null;
        if (payloadMap.get("userId") != null) {
            userId = ((Number) payloadMap.get("userId")).longValue();
        }

        if (senderId != null) {
            ClientConnection connection = new ClientConnection(session, senderId, userId);
            registry.put(session.getId(), connection);
            peerIndex.put(senderId, session.getId());

            if (userId != null) {
                userIndex.computeIfAbsent(userId, k -> ConcurrentHashMap.newKeySet()).add(session.getId());
            }
        }

        switch (type) {
            case "REGISTER_CACHE" -> {
                Object rawPayload = payloadMap.get("payload");
                Set<Integer> chunkIndices = objectMapper.convertValue(rawPayload, new TypeReference<>() {
                });

                Integer songId = payloadMap.get("songId") != null ? ((Number) payloadMap.get("songId")).intValue() : null;

                if (songId != null && senderId != null) {
                    peerTrackingService.registerPeerChunks(songId, senderId, chunkIndices);
                    log.info("[SIGNALING] REGISTER_CACHE: peer={}, songId={}, chunks={}", senderId, songId, chunkIndices.size());
                }
            }

            case "DISCOVER_PEERS" -> {
                Integer songId = ((Number) payloadMap.get("songId")).intValue();
                log.info("[SIGNALING] DISCOVER_PEERS: requester={}, songId={}", senderId, songId);
                sendBufferMaps(session, songId, senderId);
            }

            case "OFFER", "ANSWER", "ICE_CANDIDATE" -> {
                WebRTCMessage signal = objectMapper.convertValue(payloadMap, WebRTCMessage.class);
                log.info("[SIGNALING] {}: from={} to={}", type, signal.senderId(), signal.targetId());
                routeToTarget(signal);
            }

            case "SYNC_TRIGGER", "PLAYBACK_STATE_CHANGED" -> { /* Server-sent only — ignore if echoed by client */ }

            default -> {
                log.warn("[SIGNALING] Unknown signal type '{}' from session={}", type, session.getId());
                session.close(CloseStatus.BAD_DATA.withReason("Unknown signal type"));
            }
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
        String targetSessionId = peerIndex.get(signal.targetId());

        if (targetSessionId != null) {
            ClientConnection targetClient = registry.get(targetSessionId);

            if (targetClient != null && targetClient.session().isOpen()) {
                targetClient.session().sendMessage(new TextMessage(objectMapper.writeValueAsString(signal)));
            }
        }
    }
}