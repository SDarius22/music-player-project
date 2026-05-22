package com.example.musicplayerbackend.components;

import com.example.musicplayerbackend.domain.ClientConnection;
import com.example.musicplayerbackend.domain.WebRTCMessage;
import com.example.musicplayerbackend.service.JWTService;
import com.example.musicplayerbackend.service.PeerTrackingService;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.annotation.PreDestroy;
import java.io.IOException;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.ScheduledFuture;
import java.util.concurrent.TimeUnit;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.handler.TextWebSocketHandler;

@Slf4j
@Component
@RequiredArgsConstructor
public class SignalingHandler extends TextWebSocketHandler {

  @Value("${signaling.auth-timeout-ms:5000}")
  private long authTimeoutMs;

  private final ObjectMapper objectMapper;
  private final PeerTrackingService peerTrackingService;
  private final RedisTemplate<String, String> redisTemplate;
  private final JWTService jwtService;
  private final UserDetailsService userDetailsService;

  private final Map<String, ClientConnection> registry = new ConcurrentHashMap<>();
  private final Map<Long, Set<String>> userIndex = new ConcurrentHashMap<>();
  private final Map<String, String> peerIndex = new ConcurrentHashMap<>();
  private final Map<String, ScheduledFuture<?>> authTimeouts = new ConcurrentHashMap<>();

  private final ScheduledExecutorService authTimeoutScheduler =
      Executors.newSingleThreadScheduledExecutor(
          r -> {
            Thread t = new Thread(r, "signaling-auth-timeout");
            t.setDaemon(true);
            return t;
          });

  @PreDestroy
  public void shutdown() {
    authTimeoutScheduler.shutdownNow();
  }

  @Override
  public void afterConnectionEstablished(WebSocketSession session) {
    log.info("[SIGNALING] New WebSocket connection: session={}", session.getId());
    ScheduledFuture<?> future =
        authTimeoutScheduler.schedule(
            () -> closeIfUnauthenticated(session), authTimeoutMs, TimeUnit.MILLISECONDS);
    authTimeouts.put(session.getId(), future);
  }

  private void closeIfUnauthenticated(WebSocketSession session) {
    if (registry.containsKey(session.getId()) || !session.isOpen()) {
      return;
    }
    try {
      session.close(CloseStatus.POLICY_VIOLATION.withReason("auth timeout"));
    } catch (IOException e) {
      log.warn(
          "[SIGNALING] Failed to close unauthenticated session {}: {}",
          session.getId(),
          e.getMessage());
    }
  }

  @Override
  public void afterConnectionClosed(WebSocketSession session, CloseStatus status) {
    ScheduledFuture<?> future = authTimeouts.remove(session.getId());
    if (future != null) {
      future.cancel(false);
    }

    ClientConnection client = registry.remove(session.getId());
    if (client == null) {
      return;
    }

    Set<String> userSessions = userIndex.get(client.userId());
    if (userSessions != null) {
      userSessions.remove(session.getId());
      if (userSessions.isEmpty()) {
        userIndex.remove(client.userId());
      }
    }

    peerIndex.remove(client.peerId());
    peerTrackingService.unregisterPeer(client.peerId());
    log.info(
        "[SIGNALING] Peer disconnected: peerId={}, userId={}, status={}",
        client.peerId(),
        client.userId(),
        status);
  }

  @Override
  protected void handleTextMessage(WebSocketSession session, TextMessage message) throws Exception {
    Map<String, Object> payloadMap =
        objectMapper.readValue(message.getPayload(), new TypeReference<>() {});

    String type = (String) payloadMap.get("type");
    ClientConnection client = registry.get(session.getId());

    if ("AUTH".equals(type)) {
      if (client == null) {
        handleAuth(session, payloadMap);
      }
      return;
    }

    if (client == null) {
      session.close(CloseStatus.POLICY_VIOLATION.withReason("not authenticated"));
      return;
    }

    String claimedSender = (String) payloadMap.get("senderId");
    if (claimedSender != null && !claimedSender.equals(client.peerId())) {
      log.warn(
          "[SIGNALING] senderId spoof: session={} bound={} claimed={}",
          session.getId(),
          client.peerId(),
          claimedSender);
      session.close(CloseStatus.POLICY_VIOLATION.withReason("sender spoofing"));
      return;
    }

    switch (type) {
      case "REGISTER_CACHE" -> {
        Object rawPayload = payloadMap.get("payload");
        Set<Integer> chunkIndices = objectMapper.convertValue(rawPayload, new TypeReference<>() {});

        String fileHash = (String) payloadMap.get("fileHash");

        if (fileHash != null) {
          peerTrackingService.registerPeerChunks(fileHash, client.peerId(), chunkIndices);
          log.info(
              "[SIGNALING] REGISTER_CACHE: peer={}, fileHash={}, chunks={}",
              client.peerId(),
              fileHash,
              chunkIndices.size());
        }
      }

      case "DISCOVER_PEERS" -> {
        String fileHash = (String) payloadMap.get("fileHash");
        log.info(
            "[SIGNALING] DISCOVER_PEERS: requester={}, fileHash={}", client.peerId(), fileHash);
        sendBufferMaps(session, fileHash, client.peerId());
      }

      case "OFFER", "ANSWER", "ICE_CANDIDATE" -> {
        WebRTCMessage signal = objectMapper.convertValue(payloadMap, WebRTCMessage.class);
        if (!client.peerId().equals(signal.senderId())) {
          log.warn(
              "[SIGNALING] WebRTC senderId spoof: session={} bound={} claimed={}",
              session.getId(),
              client.peerId(),
              signal.senderId());
          session.close(CloseStatus.POLICY_VIOLATION.withReason("sender spoofing"));
          return;
        }
        log.info("[SIGNALING] {}: from={} to={}", type, signal.senderId(), signal.targetId());
        routeToTarget(signal);
      }

      case "PING" -> {}

      default -> {
        log.warn("[SIGNALING] Unknown signal type '{}' from session={}", type, session.getId());
        session.close(CloseStatus.BAD_DATA.withReason("Unknown signal type"));
      }
    }
  }

  private void handleAuth(WebSocketSession session, Map<String, Object> payloadMap)
      throws IOException {
    String token = (String) payloadMap.get("token");
    String senderId = (String) payloadMap.get("senderId");

    if (token == null || senderId == null || senderId.isBlank()) {
      session.close(CloseStatus.POLICY_VIOLATION.withReason("auth failed"));
      return;
    }

    Long userId;
    try {
      String username = jwtService.extractUsername(token);
      if (username == null) {
        session.close(CloseStatus.POLICY_VIOLATION.withReason("auth failed"));
        return;
      }
      UserDetails userDetails = userDetailsService.loadUserByUsername(username);
      if (!jwtService.isTokenValid(token, userDetails)) {
        session.close(CloseStatus.POLICY_VIOLATION.withReason("auth failed"));
        return;
      }
      Number userIdClaim = jwtService.extractClaim(token, claims -> (Number) claims.get("userId"));
      if (userIdClaim == null) {
        session.close(CloseStatus.POLICY_VIOLATION.withReason("auth failed"));
        return;
      }
      userId = userIdClaim.longValue();
    } catch (Exception e) {
      log.info("[SIGNALING] AUTH rejected for session={}: {}", session.getId(), e.getMessage());
      session.close(CloseStatus.POLICY_VIOLATION.withReason("auth failed"));
      return;
    }

    String existingSession = peerIndex.putIfAbsent(senderId, session.getId());
    if (existingSession != null && !existingSession.equals(session.getId())) {
      log.warn(
          "[SIGNALING] senderId {} already bound to session {}; rejecting session {}",
          senderId,
          existingSession,
          session.getId());
      session.close(CloseStatus.POLICY_VIOLATION.withReason("sender already bound"));
      return;
    }

    ClientConnection connection = new ClientConnection(session, senderId, userId);
    registry.put(session.getId(), connection);
    userIndex.computeIfAbsent(userId, k -> ConcurrentHashMap.newKeySet()).add(session.getId());

    ScheduledFuture<?> future = authTimeouts.remove(session.getId());
    if (future != null) {
      future.cancel(false);
    }

    log.info(
        "[SIGNALING] AUTH ok: session={}, peerId={}, userId={}",
        session.getId(),
        senderId,
        userId);
  }

  private void sendBufferMaps(WebSocketSession session, String fileHash, String requestingPeerId)
      throws Exception {
    Map<String, Set<Integer>> peerBufferMaps =
        new ConcurrentHashMap<>(peerTrackingService.getPeerBufferMapsForSong(fileHash));

    peerBufferMaps.remove(requestingPeerId);

    WebRTCMessage response =
        new WebRTCMessage("PEER_BUFFER_MAP", "SERVER", requestingPeerId, fileHash, peerBufferMaps);

    session.sendMessage(new TextMessage(objectMapper.writeValueAsString(response)));
  }

  private void routeToTarget(WebRTCMessage signal) throws Exception {
    if (routeToTargetLocally(signal)) {
      return;
    }
    redisTemplate.convertAndSend("signaling:webrtc", objectMapper.writeValueAsString(signal));
  }

  public boolean routeToTargetLocally(WebRTCMessage signal) {
    String targetSessionId = peerIndex.get(signal.targetId());
    if (targetSessionId == null) {
      return false;
    }

    ClientConnection targetClient = registry.get(targetSessionId);
    if (targetClient != null && targetClient.session().isOpen()) {
      try {
        targetClient
            .session()
            .sendMessage(new TextMessage(objectMapper.writeValueAsString(signal)));
        return true;
      } catch (IOException e) {
        log.error(
            "[SIGNALING] Failed to route {} to session {}: {}",
            signal.type(),
            targetSessionId,
            e.getMessage());
      }
    }
    return false;
  }
}
