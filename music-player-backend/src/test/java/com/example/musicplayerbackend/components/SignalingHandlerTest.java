package com.example.musicplayerbackend.components;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import com.example.musicplayerbackend.service.JWTService;
import com.example.musicplayerbackend.service.PeerTrackingService;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.Map;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class SignalingHandlerTest {

  @Mock PeerTrackingService peerTrackingService;
  @Mock RedisTemplate<String, String> redisTemplate;
  @Mock JWTService jwtService;
  @Mock UserDetailsService userDetailsService;
  @Mock WebSocketSession session;
  @Mock WebSocketSession session2;

  ObjectMapper objectMapper = new ObjectMapper();
  SignalingHandler handler;

  @BeforeEach
  void setUp() {
    handler =
        new SignalingHandler(
            objectMapper, peerTrackingService, redisTemplate, jwtService, userDetailsService);
    when(session.getId()).thenReturn("session-1");
    when(session2.getId()).thenReturn("session-2");
  }

  @Test
  void shouldCallRegisterPeerChunksForRegisterCacheMessage() throws Exception {
    when(peerTrackingService.getPeerBufferMapsForSong(anyString()))
        .thenReturn(java.util.Collections.emptyMap());
    authenticate(session, "peer-A", "tok-A", 1L);

    String payload =
        objectMapper.writeValueAsString(
            Map.of(
                "type", "REGISTER_CACHE",
                "senderId", "peer-A",
                "fileHash", "hash-42",
                "payload", Set.of(0, 1, 2)));

    handler.handleTextMessage(session, new TextMessage(payload));

    verify(peerTrackingService).registerPeerChunks(eq("hash-42"), eq("peer-A"), any());
  }

  @Test
  void shouldCloseSessionWhenMessageArrivesBeforeAuth() throws Exception {
    String payload =
        objectMapper.writeValueAsString(
            Map.of(
                "type", "REGISTER_CACHE",
                "senderId", "peer-A",
                "fileHash", "hash-42",
                "payload", Set.of(0, 1)));

    handler.handleTextMessage(session, new TextMessage(payload));

    verify(session).close(any(CloseStatus.class));
    verify(peerTrackingService, never()).registerPeerChunks(anyString(), any(), any());
  }

  @Test
  void shouldCloseSessionWhenAuthTokenIsInvalid() throws Exception {
    when(jwtService.extractUsername("bad")).thenReturn("user@example.com");
    UserDetails details = mock(UserDetails.class);
    when(userDetailsService.loadUserByUsername("user@example.com")).thenReturn(details);
    when(jwtService.isTokenValid("bad", details)).thenReturn(false);

    String payload =
        objectMapper.writeValueAsString(
            Map.of("type", "AUTH", "token", "bad", "senderId", "peer-A"));

    handler.handleTextMessage(session, new TextMessage(payload));

    verify(session).close(any(CloseStatus.class));
  }

  @Test
  void shouldSendBufferMapForDiscoverPeersMessage() throws Exception {
    when(peerTrackingService.getPeerBufferMapsForSong("hash-10"))
        .thenReturn(Map.of("peer-X", Set.of(0)));
    when(session.isOpen()).thenReturn(true);
    authenticate(session, "requester", "tok", 7L);

    String payload =
        objectMapper.writeValueAsString(
            Map.of("type", "DISCOVER_PEERS", "senderId", "requester", "fileHash", "hash-10"));

    handler.handleTextMessage(session, new TextMessage(payload));

    verify(session).sendMessage(any(TextMessage.class));
  }

  @Test
  void shouldRouteOfferMessageToTargetSession() throws Exception {
    authenticate(session, "peer-A", "tok-A", 1L);
    authenticate(session2, "peer-B", "tok-B", 2L);
    when(session2.isOpen()).thenReturn(true);

    String offerPayload =
        objectMapper.writeValueAsString(
            Map.of(
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
    authenticate(session, "peer-A", "tok-A", 1L);
    authenticate(session2, "peer-B", "tok-B", 2L);
    when(session2.isOpen()).thenReturn(true);

    String answerPayload =
        objectMapper.writeValueAsString(
            Map.of(
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
    authenticate(session, "peer-A", "tok-A", 1L);
    authenticate(session2, "peer-B", "tok-B", 2L);
    when(session2.isOpen()).thenReturn(true);

    String icePayload =
        objectMapper.writeValueAsString(
            Map.of(
                "type", "ICE_CANDIDATE",
                "senderId", "peer-A",
                "targetId", "peer-B",
                "fileHash", "hash-1",
                "payload", "candidate-data"));

    handler.handleTextMessage(session, new TextMessage(icePayload));

    verify(session2).sendMessage(any(TextMessage.class));
  }

  @Test
  void shouldCloseSessionWhenOfferSenderIdDoesNotMatchBinding() throws Exception {
    authenticate(session, "peer-A", "tok-A", 1L);

    String offerPayload =
        objectMapper.writeValueAsString(
            Map.of(
                "type", "OFFER",
                "senderId", "peer-IMPOSTER",
                "targetId", "peer-B",
                "fileHash", "hash-1",
                "payload", "sdp-offer"));

    handler.handleTextMessage(session, new TextMessage(offerPayload));

    verify(session).close(any(CloseStatus.class));
    verify(redisTemplate, never()).convertAndSend(anyString(), anyString());
  }

  @Test
  void shouldCloseSessionWhenTopLevelSenderIdDoesNotMatchBinding() throws Exception {
    authenticate(session, "peer-A", "tok-A", 1L);

    String payload =
        objectMapper.writeValueAsString(
            Map.of("type", "DISCOVER_PEERS", "senderId", "peer-OTHER", "fileHash", "hash"));

    handler.handleTextMessage(session, new TextMessage(payload));

    verify(session).close(any(CloseStatus.class));
  }

  @Test
  void shouldCloseSessionWhenMessageTypeIsUnknown() throws Exception {
    authenticate(session, "peer-A", "tok-A", 1L);

    String payload =
        objectMapper.writeValueAsString(
            Map.of("type", "TOTALLY_UNKNOWN", "senderId", "peer-A"));

    handler.handleTextMessage(session, new TextMessage(payload));

    verify(session).close(any(CloseStatus.class));
  }

  @Test
  void shouldDoNothingWhenClosedSessionWasNotRegistered() {
    handler.afterConnectionClosed(session, CloseStatus.NORMAL);

    verify(peerTrackingService, never()).unregisterPeer(any());
  }

  @Test
  void shouldUnregisterPeerWhenAuthenticatedSessionCloses() throws Exception {
    authenticate(session, "peer-to-remove", "tok", 5L);

    handler.afterConnectionClosed(session, CloseStatus.NORMAL);

    verify(peerTrackingService).unregisterPeer("peer-to-remove");
  }

  @Test
  void shouldSkipRegisterPeerChunksWhenFileHashIsNull() throws Exception {
    authenticate(session, "peer-A", "tok-A", 1L);

    String payload =
        objectMapper.writeValueAsString(
            Map.of("type", "REGISTER_CACHE", "senderId", "peer-A", "payload", Set.of(0, 1, 2)));

    handler.handleTextMessage(session, new TextMessage(payload));

    verify(peerTrackingService, never()).registerPeerChunks(anyString(), any(), any());
  }

  @Test
  void shouldPublishToRedisWhenOfferTargetIsNotInLocalPeerIndex() throws Exception {
    authenticate(session, "peer-A", "tok-A", 1L);

    String payload =
        objectMapper.writeValueAsString(
            Map.of(
                "type", "OFFER",
                "senderId", "peer-A",
                "targetId", "nonexistent-peer",
                "fileHash", "hash-1",
                "payload", "sdp"));

    assertDoesNotThrow(() -> handler.handleTextMessage(session, new TextMessage(payload)));
    verify(redisTemplate).convertAndSend(eq("signaling:webrtc"), anyString());
  }

  @Test
  void shouldPublishToRedisWhenOfferTargetSessionIsClosed() throws Exception {
    authenticate(session, "peer-A", "tok-A", 1L);
    authenticate(session2, "peer-C", "tok-C", 2L);
    when(session2.isOpen()).thenReturn(false);

    String offerPayload =
        objectMapper.writeValueAsString(
            Map.of(
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
  void shouldLogWhenConnectionEstablished() {
    assertDoesNotThrow(() -> handler.afterConnectionEstablished(session));
  }

  private void authenticate(WebSocketSession s, String senderId, String token, Long userId)
      throws Exception {
    String username = senderId + "@example.com";
    UserDetails details = mock(UserDetails.class);
    when(jwtService.extractUsername(token)).thenReturn(username);
    when(userDetailsService.loadUserByUsername(username)).thenReturn(details);
    when(jwtService.isTokenValid(token, details)).thenReturn(true);
    when(jwtService.extractClaim(eq(token), any())).thenReturn(userId);

    String payload =
        objectMapper.writeValueAsString(
            Map.of("type", "AUTH", "token", token, "senderId", senderId));
    handler.handleTextMessage(s, new TextMessage(payload));
  }
}
