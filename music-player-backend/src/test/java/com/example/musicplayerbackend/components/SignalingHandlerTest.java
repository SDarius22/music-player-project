package com.example.musicplayerbackend.components;

import com.example.musicplayerbackend.service.PeerTrackingService;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;

import java.io.IOException;
import java.util.Map;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class SignalingHandlerTest {

    @Mock
    PeerTrackingService peerTrackingService;
    @Mock
    RedisTemplate<String, String> redisTemplate;
    @Mock
    WebSocketSession session;
    @Mock
    WebSocketSession session2;

    ObjectMapper objectMapper = new ObjectMapper();
    SignalingHandler handler;

    @BeforeEach
    void setUp() {
        handler = new SignalingHandler(objectMapper, peerTrackingService, redisTemplate);
        when(session.getId()).thenReturn("session-1");
        when(session2.getId()).thenReturn("session-2");
    }

    @Test
    void shouldCallRegisterPeerChunksForRegisterCacheMessage() throws Exception {
        when(peerTrackingService.getPeerBufferMapsForSong(anyString()))
                .thenReturn(java.util.Collections.emptyMap());

        String payload = objectMapper.writeValueAsString(Map.of(
                "type", "REGISTER_CACHE",
                "senderId", "peer-A",
                "userId", 1,
                "fileHash", "hash-42",
                "payload", Set.of(0, 1, 2)));

        handler.handleTextMessage(session, new TextMessage(payload));

        verify(peerTrackingService).registerPeerChunks(eq("hash-42"), eq("peer-A"), any());
    }

    @Test
    void shouldSkipRegistrationWhenRegisterCacheSenderIdIsNull() throws Exception {
        String payload = objectMapper.writeValueAsString(Map.of(
                "type", "REGISTER_CACHE",
                "fileHash", "hash-42",
                "payload", Set.of(0, 1)));

        handler.handleTextMessage(session, new TextMessage(payload));

        verify(peerTrackingService, never()).registerPeerChunks(anyString(), any(), any());
    }

    @Test
    void shouldSendBufferMapForDiscoverPeersMessage() throws Exception {
        when(peerTrackingService.getPeerBufferMapsForSong("hash-10"))
                .thenReturn(Map.of("peer-X", Set.of(0)));
        when(session.isOpen()).thenReturn(true);

        String payload = objectMapper.writeValueAsString(Map.of(
                "type", "DISCOVER_PEERS",
                "senderId", "requester",
                "fileHash", "hash-10"));

        handler.handleTextMessage(session, new TextMessage(payload));

        verify(session).sendMessage(any(TextMessage.class));
    }

    @Test
    void shouldRouteOfferMessageToTargetSession() throws Exception {
        // Register session2 as peer-B first
        String registerPayload = objectMapper.writeValueAsString(Map.of(
                "type", "PING",
                "senderId", "peer-B",
                "userId", 2));
        handler.handleTextMessage(session2, new TextMessage(registerPayload));
        when(session2.isOpen()).thenReturn(true);

        // Now send OFFER from session1 to peer-B
        String offerPayload = objectMapper.writeValueAsString(Map.of(
                "type", "OFFER",
                "senderId", "peer-A",
                "targetId", "peer-B",
                "fileHash", "hash-1",
                "payload", "sdp-offer"));

        handler.handleTextMessage(session, new TextMessage(offerPayload));

        verify(session2).sendMessage(any(TextMessage.class));
    }

    @Test
    void shouldRouteAnswerMessageToTargetSession() throws Exception {
        when(session2.isOpen()).thenReturn(true);
        // Register session2 as peer-B
        String registerPayload = objectMapper.writeValueAsString(Map.of(
                "type", "PING",
                "senderId", "peer-B",
                "userId", 2));
        handler.handleTextMessage(session2, new TextMessage(registerPayload));

        String answerPayload = objectMapper.writeValueAsString(Map.of(
                "type", "ANSWER",
                "senderId", "peer-A",
                "targetId", "peer-B",
                "fileHash", "hash-1",
                "payload", "sdp-answer"));

        handler.handleTextMessage(session, new TextMessage(answerPayload));

        verify(session2).sendMessage(any(TextMessage.class));
    }

    @Test
    void shouldRouteIceCandidateMessageToTargetSession() throws Exception {
        when(session2.isOpen()).thenReturn(true);
        String registerPayload = objectMapper.writeValueAsString(Map.of(
                "type", "PING",
                "senderId", "peer-B",
                "userId", 2));
        handler.handleTextMessage(session2, new TextMessage(registerPayload));

        String icePayload = objectMapper.writeValueAsString(Map.of(
                "type", "ICE_CANDIDATE",
                "senderId", "peer-A",
                "targetId", "peer-B",
                "fileHash", "hash-1",
                "payload", "candidate-data"));

        handler.handleTextMessage(session, new TextMessage(icePayload));

        verify(session2).sendMessage(any(TextMessage.class));
    }

    @Test
    void shouldCloseSessionWhenMessageTypeIsUnknown() throws Exception {
        String payload = objectMapper.writeValueAsString(Map.of(
                "type", "TOTALLY_UNKNOWN",
                "senderId", "peer-A",
                "userId", 1));

        handler.handleTextMessage(session, new TextMessage(payload));

        verify(session).close(any(CloseStatus.class));
    }


    @Test
    void shouldDoNothingWhenClosedSessionWasNotRegistered() {
        handler.afterConnectionClosed(session, CloseStatus.NORMAL);

        verify(peerTrackingService, never()).unregisterPeer(any());
    }

    @Test
    void shouldUnregisterPeerWhenRegisteredSessionWithPeerIdCloses() throws Exception {
        // Register session first
        String registerPayload = objectMapper.writeValueAsString(Map.of(
                "type", "PING",
                "senderId", "peer-to-remove",
                "userId", 5));
        handler.handleTextMessage(session, new TextMessage(registerPayload));

        handler.afterConnectionClosed(session, CloseStatus.NORMAL);

        verify(peerTrackingService).unregisterPeer("peer-to-remove");
    }

    @Test
    void shouldNotUnregisterPeerWhenRegisteredSessionHasNoPeerId() throws Exception {
        // Register session without senderId (peerId stays null)
        String registerPayload = objectMapper.writeValueAsString(Map.of(
                "type", "PING",
                "userId", 5));
        handler.handleTextMessage(session, new TextMessage(registerPayload));

        handler.afterConnectionClosed(session, CloseStatus.NORMAL);

        verify(peerTrackingService, never()).unregisterPeer(any());
    }

    @Test
    void shouldSkipRegisterPeerChunksWhenRegisterCacheFileHashIsNull() throws Exception {
        // fileHash absent → condition (fileHash != null && senderId != null) is false
        String payload = objectMapper.writeValueAsString(Map.of(
                "type", "REGISTER_CACHE",
                "senderId", "peer-A",
                "userId", 1,
                "payload", Set.of(0, 1, 2)));

        handler.handleTextMessage(session, new TextMessage(payload));

        verify(peerTrackingService, never()).registerPeerChunks(anyString(), any(), any());
    }

    @Test
    void shouldPublishToRedisWhenOfferTargetIsNotInLocalPeerIndex() throws Exception {
        // targetId not registered locally — falls back to Redis pub/sub
        String payload = objectMapper.writeValueAsString(Map.of(
                "type", "OFFER",
                "senderId", "peer-A",
                "targetId", "nonexistent-peer",
                "fileHash", "hash-1",
                "payload", "sdp"));

        assertDoesNotThrow(() -> handler.handleTextMessage(session, new TextMessage(payload)));
        verify(session, never()).sendMessage(any(TextMessage.class));
        verify(redisTemplate).convertAndSend(eq("signaling:webrtc"), anyString());
    }

    @Test
    void shouldPublishToRedisWhenOfferTargetSessionIsClosed() throws Exception {
        // Register session2 as peer-C but mark it closed — falls back to Redis pub/sub
        String registerPayload = objectMapper.writeValueAsString(Map.of(
                "type", "PING",
                "senderId", "peer-C",
                "userId", 2));
        handler.handleTextMessage(session2, new TextMessage(registerPayload));
        when(session2.isOpen()).thenReturn(false);

        String offerPayload = objectMapper.writeValueAsString(Map.of(
                "type", "OFFER",
                "senderId", "peer-A",
                "targetId", "peer-C",
                "fileHash", "hash-1",
                "payload", "sdp-offer"));

        handler.handleTextMessage(session, new TextMessage(offerPayload));

        verify(session2, never()).sendMessage(any(TextMessage.class));
        verify(redisTemplate).convertAndSend(eq("signaling:webrtc"), anyString());
    }

    @Test
    void shouldSkipUserIndexCleanupWhenClientHasNullUserId() throws Exception {
        // Register session with senderId but no userId → ClientConnection.userId() == null
        String payload = objectMapper.writeValueAsString(Map.of(
                "type", "PING",
                "senderId", "peer-no-user"));
        handler.handleTextMessage(session, new TextMessage(payload));

        handler.afterConnectionClosed(session, CloseStatus.NORMAL);

        // peerId cleanup still happens, but userId block is skipped without NPE
        verify(peerTrackingService).unregisterPeer("peer-no-user");
    }

    @Test
    void shouldLogWhenConnectionEstablished() {
        assertDoesNotThrow(() -> handler.afterConnectionEstablished(session));
    }
}
