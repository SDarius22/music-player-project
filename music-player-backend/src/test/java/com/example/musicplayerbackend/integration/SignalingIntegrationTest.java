package com.example.musicplayerbackend.integration;

import static org.junit.jupiter.api.Assertions.*;

import com.example.musicplayerbackend.data.UserRepository;
import com.example.musicplayerbackend.domain.AuthProvider;
import com.example.musicplayerbackend.domain.Role;
import com.example.musicplayerbackend.domain.User;
import com.example.musicplayerbackend.domain.WebRTCMessage;
import com.example.musicplayerbackend.service.JWTService;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.client.standard.StandardWebSocketClient;
import org.springframework.web.socket.handler.TextWebSocketHandler;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

@Testcontainers
@SpringBootTest(
    webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
    properties = {
      "MAIL_HOST=localhost",
      "MAIL_USER=test@example.com",
      "MAIL_PASSWORD=test",
      "signaling.auth-timeout-ms=400"
    })
class SignalingIntegrationTest {

  @Container @ServiceConnection
  static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:latest");

  @Container
  @SuppressWarnings("resource")
  static GenericContainer<?> redis =
      new GenericContainer<>("redis:7-alpine").withExposedPorts(6379);

  @DynamicPropertySource
  static void configureRedis(DynamicPropertyRegistry registry) {
    registry.add("spring.data.redis.host", redis::getHost);
    registry.add("spring.data.redis.port", () -> redis.getMappedPort(6379));
  }

  @LocalServerPort private int port;

  @Autowired private ObjectMapper objectMapper;
  @Autowired private JWTService jwtService;
  @Autowired private UserRepository userRepository;

  @Test
  void shouldRegisterAndDiscoverPeerBufferMaps() throws Exception {
    User user1 = userRepository.save(buildUser("signaling-1@example.com"));
    User user2 = userRepository.save(buildUser("signaling-2@example.com"));
    String token1 = jwtService.generateAccessToken(user1);
    String token2 = jwtService.generateAccessToken(user2);

    StandardWebSocketClient client = new StandardWebSocketClient();
    String wsUrl = "ws://localhost:" + port + "/ws/signaling";

    TestSocketHandler peer1Handler = new TestSocketHandler();
    TestSocketHandler peer2Handler = new TestSocketHandler();

    WebSocketSession peer1Session = client.execute(peer1Handler, wsUrl).get(5, TimeUnit.SECONDS);
    WebSocketSession peer2Session = client.execute(peer2Handler, wsUrl).get(5, TimeUnit.SECONDS);

    String peer1Id = "flutter-device-1";
    String peer2Id = "flutter-device-2";

    authenticate(peer1Session, peer1Id, token1);
    authenticate(peer2Session, peer2Id, token2);

    WebRTCMessage registerSignal =
        new WebRTCMessage("REGISTER_CACHE", peer1Id, null, "hash-1", Set.of(0, 1, 2, 3));
    peer1Session.sendMessage(new TextMessage(objectMapper.writeValueAsString(registerSignal)));

    Map<String, List<Integer>> payloadMap =
        awaitPeerVisibleViaDiscover(
            peer2Session, peer2Handler, peer2Id, peer1Id, Duration.ofSeconds(5));

    List<Integer> peer1Chunks = payloadMap.get(peer1Id);
    assertNotNull(peer1Chunks, "Peer 2 should see Peer 1 in the map");
    assertEquals(4, peer1Chunks.size());
    assertTrue(peer1Chunks.containsAll(List.of(0, 1, 2, 3)));

    peer1Session.close();
    peer2Session.close();
  }

  @Test
  void shouldCloseSessionWhenMessageArrivesBeforeAuth() throws Exception {
    StandardWebSocketClient client = new StandardWebSocketClient();
    String wsUrl = "ws://localhost:" + port + "/ws/signaling";

    TestSocketHandler handler = new TestSocketHandler();
    WebSocketSession session = client.execute(handler, wsUrl).get(5, TimeUnit.SECONDS);

    WebRTCMessage registerSignal =
        new WebRTCMessage("REGISTER_CACHE", "spoof", null, "hash-x", Set.of(0));
    session.sendMessage(new TextMessage(objectMapper.writeValueAsString(registerSignal)));

    CloseStatus status = handler.awaitClose(Duration.ofSeconds(2));
    assertNotNull(status, "Server should close the unauthenticated session");
    assertEquals(CloseStatus.POLICY_VIOLATION.getCode(), status.getCode());
  }

  @Test
  void shouldRejectInvalidToken() throws Exception {
    StandardWebSocketClient client = new StandardWebSocketClient();
    String wsUrl = "ws://localhost:" + port + "/ws/signaling";

    TestSocketHandler handler = new TestSocketHandler();
    WebSocketSession session = client.execute(handler, wsUrl).get(5, TimeUnit.SECONDS);

    session.sendMessage(
        new TextMessage(
            objectMapper.writeValueAsString(
                Map.of("type", "AUTH", "token", "not-a-valid-jwt", "senderId", "peer-x"))));

    CloseStatus status = handler.awaitClose(Duration.ofSeconds(2));
    assertNotNull(status, "Server should close on invalid token");
    assertEquals(CloseStatus.POLICY_VIOLATION.getCode(), status.getCode());
  }

  @Test
  void shouldCloseOnSenderIdSpoofAfterAuth() throws Exception {
    User user = userRepository.save(buildUser("signaling-spoof@example.com"));
    String token = jwtService.generateAccessToken(user);

    StandardWebSocketClient client = new StandardWebSocketClient();
    String wsUrl = "ws://localhost:" + port + "/ws/signaling";

    TestSocketHandler handler = new TestSocketHandler();
    WebSocketSession session = client.execute(handler, wsUrl).get(5, TimeUnit.SECONDS);

    authenticate(session, "peer-real", token);

    WebRTCMessage offer =
        new WebRTCMessage(
            "OFFER", "peer-other", "peer-target", null, Map.of("sdp", "x", "type", "offer"));
    session.sendMessage(new TextMessage(objectMapper.writeValueAsString(offer)));

    CloseStatus status = handler.awaitClose(Duration.ofSeconds(2));
    assertNotNull(status, "Server should close on senderId spoof");
    assertEquals(CloseStatus.POLICY_VIOLATION.getCode(), status.getCode());
  }

  @Test
  void shouldCloseIdleSessionAfterAuthTimeout() throws Exception {
    StandardWebSocketClient client = new StandardWebSocketClient();
    String wsUrl = "ws://localhost:" + port + "/ws/signaling";

    TestSocketHandler handler = new TestSocketHandler();
    WebSocketSession session = client.execute(handler, wsUrl).get(5, TimeUnit.SECONDS);

    CloseStatus status = handler.awaitClose(Duration.ofSeconds(3));
    assertNotNull(status, "Server should close idle unauthenticated session");
    assertEquals(CloseStatus.POLICY_VIOLATION.getCode(), status.getCode());
  }

  private void authenticate(WebSocketSession session, String senderId, String token)
      throws Exception {
    session.sendMessage(
        new TextMessage(
            objectMapper.writeValueAsString(
                Map.of("type", "AUTH", "token", token, "senderId", senderId))));
  }

  private User buildUser(String email) {
    return userRepository.save(
        User.builder()
            .email(email)
            .role(Role.USER)
            .provider(AuthProvider.LOCAL)
            .createdAt(Instant.now())
            .build());
  }

  private Map<String, List<Integer>> awaitPeerVisibleViaDiscover(
      WebSocketSession discoverSession,
      TestSocketHandler discoverHandler,
      String discovererId,
      String expectedPeerId,
      Duration timeout)
      throws Exception {
    long deadlineNanos = System.nanoTime() + timeout.toNanos();
    TypeReference<Map<String, List<Integer>>> typeRef = new TypeReference<>() {};

    while (System.nanoTime() < deadlineNanos) {
      WebRTCMessage discoverSignal =
          new WebRTCMessage("DISCOVER_PEERS", discovererId, null, "hash-1", null);
      discoverSession.sendMessage(new TextMessage(objectMapper.writeValueAsString(discoverSignal)));

      String raw = discoverHandler.nextMessage(500, TimeUnit.MILLISECONDS);
      if (raw == null || raw.isBlank()) {
        continue;
      }

      WebRTCMessage response = objectMapper.readValue(raw, WebRTCMessage.class);
      if (!"PEER_BUFFER_MAP".equals(response.type())) {
        continue;
      }

      Map<String, List<Integer>> payloadMap =
          objectMapper.convertValue(response.payload(), typeRef);
      if (payloadMap != null && payloadMap.containsKey(expectedPeerId)) {
        return payloadMap;
      }
    }

    fail("Timed out waiting for " + expectedPeerId + " to appear in PEER_BUFFER_MAP");
    return Map.of();
  }

  private static class TestSocketHandler extends TextWebSocketHandler {
    private final BlockingQueue<String> messages = new LinkedBlockingQueue<>();
    private final BlockingQueue<CloseStatus> closes = new LinkedBlockingQueue<>();

    @Override
    protected void handleTextMessage(WebSocketSession session, TextMessage message) {
      messages.offer(message.getPayload());
    }

    @Override
    public void afterConnectionClosed(WebSocketSession session, CloseStatus status) {
      closes.offer(status);
    }

    String nextMessage(long timeout, TimeUnit unit) throws InterruptedException {
      return messages.poll(timeout, unit);
    }

    CloseStatus awaitClose(Duration timeout) throws InterruptedException {
      return closes.poll(timeout.toMillis(), TimeUnit.MILLISECONDS);
    }
  }
}
