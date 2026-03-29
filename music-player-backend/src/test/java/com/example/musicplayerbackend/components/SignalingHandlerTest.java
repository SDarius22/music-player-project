package com.example.musicplayerbackend.components;

import com.example.musicplayerbackend.domain.PlaybackStateDto;
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
        when(peerTrackingService.getPeerBufferMapsForSong(anyInt()))
                .thenReturn(java.util.Collections.emptyMap());

        String payload = objectMapper.writeValueAsString(Map.of(
                "type", "REGISTER_CACHE",
                "senderId", "peer-A",
                "userId", 1,
                "songId", 42,
                "payload", Set.of(0, 1, 2)));

        handler.handleTextMessage(session, new TextMessage(payload));

        verify(peerTrackingService).registerPeerChunks(eq(42), eq("peer-A"), any());
    }

    @Test
    void shouldSkipRegistrationWhenRegisterCacheSenderIdIsNull() throws Exception {
        String payload = objectMapper.writeValueAsString(Map.of(
                "type", "REGISTER_CACHE",
                "songId", 42,
                "payload", Set.of(0, 1)));

        handler.handleTextMessage(session, new TextMessage(payload));

        verify(peerTrackingService, never()).registerPeerChunks(anyInt(), any(), any());
    }

    @Test
    void shouldSendBufferMapForDiscoverPeersMessage() throws Exception {
        when(peerTrackingService.getPeerBufferMapsForSong(10))
                .thenReturn(Map.of("peer-X", Set.of(0)));
        when(session.isOpen()).thenReturn(true);

        String payload = objectMapper.writeValueAsString(Map.of(
                "type", "DISCOVER_PEERS",
                "senderId", "requester",
                "songId", 10));

        handler.handleTextMessage(session, new TextMessage(payload));

        verify(session).sendMessage(any(TextMessage.class));
    }

    @Test
    void shouldRouteOfferMessageToTargetSession() throws Exception {
        // Register session2 as peer-B first
        String registerPayload = objectMapper.writeValueAsString(Map.of(
                "type", "SYNC_TRIGGER",
                "senderId", "peer-B",
                "userId", 2));
        handler.handleTextMessage(session2, new TextMessage(registerPayload));
        when(session2.isOpen()).thenReturn(true);

        // Now send OFFER from session1 to peer-B
        String offerPayload = objectMapper.writeValueAsString(Map.of(
                "type", "OFFER",
                "senderId", "peer-A",
                "targetId", "peer-B",
                "songId", 1,
                "payload", "sdp-offer"));

        handler.handleTextMessage(session, new TextMessage(offerPayload));

        verify(session2).sendMessage(any(TextMessage.class));
    }

    @Test
    void shouldRouteAnswerMessageToTargetSession() throws Exception {
        when(session2.isOpen()).thenReturn(true);
        // Register session2 as peer-B
        String registerPayload = objectMapper.writeValueAsString(Map.of(
                "type", "SYNC_TRIGGER",
                "senderId", "peer-B",
                "userId", 2));
        handler.handleTextMessage(session2, new TextMessage(registerPayload));

        String answerPayload = objectMapper.writeValueAsString(Map.of(
                "type", "ANSWER",
                "senderId", "peer-A",
                "targetId", "peer-B",
                "songId", 1,
                "payload", "sdp-answer"));

        handler.handleTextMessage(session, new TextMessage(answerPayload));

        verify(session2).sendMessage(any(TextMessage.class));
    }

    @Test
    void shouldRouteIceCandidateMessageToTargetSession() throws Exception {
        when(session2.isOpen()).thenReturn(true);
        String registerPayload = objectMapper.writeValueAsString(Map.of(
                "type", "SYNC_TRIGGER",
                "senderId", "peer-B",
                "userId", 2));
        handler.handleTextMessage(session2, new TextMessage(registerPayload));

        String icePayload = objectMapper.writeValueAsString(Map.of(
                "type", "ICE_CANDIDATE",
                "senderId", "peer-A",
                "targetId", "peer-B",
                "songId", 1,
                "payload", "candidate-data"));

        handler.handleTextMessage(session, new TextMessage(icePayload));

        verify(session2).sendMessage(any(TextMessage.class));
    }

    @Test
    void shouldDoNothingForSyncTriggerMessage() throws Exception {
        String payload = objectMapper.writeValueAsString(Map.of(
                "type", "SYNC_TRIGGER",
                "senderId", "server",
                "userId", 1));

        handler.handleTextMessage(session, new TextMessage(payload));

        // No interaction with peerTrackingService for sync trigger echoes
        verify(peerTrackingService, never()).registerPeerChunks(anyInt(), any(), any());
        verify(session, never()).close(any());
    }

    @Test
    void shouldDoNothingForPlaybackStateChangedMessage() throws Exception {
        String payload = objectMapper.writeValueAsString(Map.of(
                "type", "PLAYBACK_STATE_CHANGED",
                "senderId", "server",
                "userId", 1));

        handler.handleTextMessage(session, new TextMessage(payload));

        verify(session, never()).close(any());
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
                "type", "SYNC_TRIGGER",
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
                "type", "SYNC_TRIGGER",
                "userId", 5));
        handler.handleTextMessage(session, new TextMessage(registerPayload));

        handler.afterConnectionClosed(session, CloseStatus.NORMAL);

        verify(peerTrackingService, never()).unregisterPeer(any());
    }

    @Test
    void shouldSendNothingWhenDeliveringSyncTriggerWithNoSessionsForUser() throws Exception {
        // user 999 has no sessions registered
        handler.deliverSyncTriggerLocally(999L);

        verify(session, never()).sendMessage(any());
    }

    @Test
    void shouldSendSyncTriggerToOpenSession() throws Exception {
        // Register session for user 10
        String registerPayload = objectMapper.writeValueAsString(Map.of(
                "type", "SYNC_TRIGGER",
                "senderId", "peer-deliver",
                "userId", 10));
        handler.handleTextMessage(session, new TextMessage(registerPayload));
        when(session.isOpen()).thenReturn(true);

        handler.deliverSyncTriggerLocally(10L);

        verify(session).sendMessage(any(TextMessage.class));
    }

    @Test
    void shouldNotSendSyncTriggerToClosedSession() throws Exception {
        // Register session for user 11
        String registerPayload = objectMapper.writeValueAsString(Map.of(
                "type", "SYNC_TRIGGER",
                "senderId", "peer-closed",
                "userId", 11));
        handler.handleTextMessage(session, new TextMessage(registerPayload));
        when(session.isOpen()).thenReturn(false);

        handler.deliverSyncTriggerLocally(11L);

        verify(session, never()).sendMessage(any());
    }

    @Test
    void shouldSendNothingWhenDeliveringPlaybackStateWithNoSessionsForUser() throws Exception {
        handler.deliverPlaybackStateChangedLocally(888L, new PlaybackStateDto());

        verify(session, never()).sendMessage(any());
    }

    @Test
    void shouldSendPlaybackStateChangedPayloadToOpenSession() throws Exception {
        // Register session for user 20
        String registerPayload = objectMapper.writeValueAsString(Map.of(
                "type", "SYNC_TRIGGER",
                "senderId", "peer-pb",
                "userId", 20));
        handler.handleTextMessage(session, new TextMessage(registerPayload));
        when(session.isOpen()).thenReturn(true);

        handler.deliverPlaybackStateChangedLocally(20L, new PlaybackStateDto());

        ArgumentCaptor<TextMessage> captor = ArgumentCaptor.forClass(TextMessage.class);
        verify(session).sendMessage(captor.capture());
        assertTrue(captor.getValue().getPayload().contains("PLAYBACK_STATE_CHANGED"));
    }

    @Test
    void shouldPublishSyncTriggerToRedis() {
        handler.sendSyncTrigger(42L);

        verify(redisTemplate).convertAndSend("signaling:sync", "42");
    }

    @Test
    void shouldPublishPlaybackStateChangedToRedis() {
        handler.sendPlaybackStateChanged(7L, new PlaybackStateDto());

        verify(redisTemplate).convertAndSend(eq("signaling:playback"), anyString());
    }

    @Test
    void shouldLogAndNotThrowWhenPlaybackStateSerializationFails() throws Exception {
        // Use a handler with a mock ObjectMapper that throws on serialization
        ObjectMapper brokenMapper = mock(ObjectMapper.class);
        when(brokenMapper.writeValueAsString(any())).thenThrow(new JsonProcessingException("mock fail") {
        });
        SignalingHandler brokenHandler = new SignalingHandler(brokenMapper, peerTrackingService, redisTemplate);

        // Should not throw even when ObjectMapper fails
        assertDoesNotThrow(() -> brokenHandler.sendPlaybackStateChanged(1L, new PlaybackStateDto()));

        verify(redisTemplate, never()).convertAndSend(any(), any(Object.class));
    }

    @Test
    void shouldRegisterSessionButNotUpdateUserIndexWhenUserIdIsAbsent() throws Exception {
        // senderId present, userId absent → session registered but userIndex not updated
        String payload = objectMapper.writeValueAsString(Map.of(
                "type", "SYNC_TRIGGER",
                "senderId", "peer-no-user-id"));

        handler.handleTextMessage(session, new TextMessage(payload));

        // No sessions mapped for any userId, so delivering to any user should not reach session
        handler.deliverSyncTriggerLocally(999L);
        verify(session, never()).sendMessage(any());
    }

    @Test
    void shouldSkipRegisterPeerChunksWhenRegisterCacheSongIdIsNull() throws Exception {
        // songId absent → condition (songId != null && senderId != null) is false
        String payload = objectMapper.writeValueAsString(Map.of(
                "type", "REGISTER_CACHE",
                "senderId", "peer-A",
                "userId", 1,
                "payload", Set.of(0, 1, 2)));

        handler.handleTextMessage(session, new TextMessage(payload));

        verify(peerTrackingService, never()).registerPeerChunks(anyInt(), any(), any());
    }

    @Test
    void shouldPublishToRedisWhenOfferTargetIsNotInLocalPeerIndex() throws Exception {
        // targetId not registered locally — falls back to Redis pub/sub
        String payload = objectMapper.writeValueAsString(Map.of(
                "type", "OFFER",
                "senderId", "peer-A",
                "targetId", "nonexistent-peer",
                "songId", 1,
                "payload", "sdp"));

        assertDoesNotThrow(() -> handler.handleTextMessage(session, new TextMessage(payload)));
        verify(session, never()).sendMessage(any(TextMessage.class));
        verify(redisTemplate).convertAndSend(eq("signaling:webrtc"), anyString());
    }

    @Test
    void shouldPublishToRedisWhenOfferTargetSessionIsClosed() throws Exception {
        // Register session2 as peer-C but mark it closed — falls back to Redis pub/sub
        String registerPayload = objectMapper.writeValueAsString(Map.of(
                "type", "SYNC_TRIGGER",
                "senderId", "peer-C",
                "userId", 2));
        handler.handleTextMessage(session2, new TextMessage(registerPayload));
        when(session2.isOpen()).thenReturn(false);

        String offerPayload = objectMapper.writeValueAsString(Map.of(
                "type", "OFFER",
                "senderId", "peer-A",
                "targetId", "peer-C",
                "songId", 1,
                "payload", "sdp-offer"));

        handler.handleTextMessage(session, new TextMessage(offerPayload));

        verify(session2, never()).sendMessage(any(TextMessage.class));
        verify(redisTemplate).convertAndSend(eq("signaling:webrtc"), anyString());
    }

    @Test
    void shouldRetainUserIndexEntryWhenUserHasOtherSessionsAfterClose() throws Exception {
        // Register two sessions for user 50
        String payload1 = objectMapper.writeValueAsString(Map.of(
                "type", "SYNC_TRIGGER",
                "senderId", "peer-s1",
                "userId", 50));
        handler.handleTextMessage(session, new TextMessage(payload1));

        String payload2 = objectMapper.writeValueAsString(Map.of(
                "type", "SYNC_TRIGGER",
                "senderId", "peer-s2",
                "userId", 50));
        handler.handleTextMessage(session2, new TextMessage(payload2));

        // Close session1 — userSessions still has session2, so userIndex entry is retained
        handler.afterConnectionClosed(session, CloseStatus.NORMAL);

        when(session2.isOpen()).thenReturn(true);
        handler.deliverSyncTriggerLocally(50L);
        verify(session2).sendMessage(any(TextMessage.class));
    }

    @Test
    void shouldSkipUserIndexCleanupWhenClientHasNullUserId() throws Exception {
        // Register session with senderId but no userId → ClientConnection.userId() == null
        String payload = objectMapper.writeValueAsString(Map.of(
                "type", "SYNC_TRIGGER",
                "senderId", "peer-no-user"));
        handler.handleTextMessage(session, new TextMessage(payload));

        handler.afterConnectionClosed(session, CloseStatus.NORMAL);

        // peerId cleanup still happens, but userId block is skipped without NPE
        verify(peerTrackingService).unregisterPeer("peer-no-user");
    }

    @Test
    void shouldNotSendPlaybackStateChangedToClosedSession() throws Exception {
        String registerPayload = objectMapper.writeValueAsString(Map.of(
                "type", "SYNC_TRIGGER",
                "senderId", "peer-pb-closed",
                "userId", 21));
        handler.handleTextMessage(session, new TextMessage(registerPayload));
        when(session.isOpen()).thenReturn(false);

        handler.deliverPlaybackStateChangedLocally(21L, new PlaybackStateDto());

        verify(session, never()).sendMessage(any());
    }

    @Test
    void shouldReturnEarlyWhenDeliverPlaybackStateChangedSerializationFails() throws Exception {
        ObjectMapper brokenMapper = mock(ObjectMapper.class);
        when(brokenMapper.writeValueAsString(any())).thenThrow(new JsonProcessingException("fail") {
        });
        SignalingHandler brokenHandler = new SignalingHandler(brokenMapper, peerTrackingService, redisTemplate);

        assertDoesNotThrow(() -> brokenHandler.deliverPlaybackStateChangedLocally(1L, new PlaybackStateDto()));

        verify(session, never()).sendMessage(any());
    }

    @Test
    void shouldHandleIOExceptionWhenSendingPlaybackStateChangedToSession() throws Exception {
        String registerPayload = objectMapper.writeValueAsString(Map.of(
                "type", "SYNC_TRIGGER",
                "senderId", "peer-pb-io",
                "userId", 40));
        handler.handleTextMessage(session, new TextMessage(registerPayload));
        when(session.isOpen()).thenReturn(true);
        doThrow(new IOException("send failed")).when(session).sendMessage(any(TextMessage.class));

        assertDoesNotThrow(() -> handler.deliverPlaybackStateChangedLocally(40L, new PlaybackStateDto()));
    }

    @Test
    void shouldHandleIOExceptionWhenSendingSyncTriggerToSession() throws Exception {
        String registerPayload = objectMapper.writeValueAsString(Map.of(
                "type", "SYNC_TRIGGER",
                "senderId", "peer-io",
                "userId", 30));
        handler.handleTextMessage(session, new TextMessage(registerPayload));
        when(session.isOpen()).thenReturn(true);
        doThrow(new IOException("send failed")).when(session).sendMessage(any(TextMessage.class));

        assertDoesNotThrow(() -> handler.deliverSyncTriggerLocally(30L));
    }

    @Test
    void shouldLogWhenConnectionEstablished() {
        assertDoesNotThrow(() -> handler.afterConnectionEstablished(session));
    }
}
