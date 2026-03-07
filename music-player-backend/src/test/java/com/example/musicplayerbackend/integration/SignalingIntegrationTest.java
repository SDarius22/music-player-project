package com.example.musicplayerbackend.integration;

import com.example.musicplayerbackend.domain.WebRTCMessage;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.client.standard.StandardWebSocketClient;
import org.springframework.web.socket.handler.TextWebSocketHandler;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import java.time.Duration;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.TimeUnit;

import static org.junit.jupiter.api.Assertions.*;

@Testcontainers
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class SignalingIntegrationTest {

    @Container
    @ServiceConnection
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:latest");

    @LocalServerPort
    private int port;

    @Autowired
    private ObjectMapper objectMapper;

    @Test
    void shouldRegisterAndDiscoverPeerBufferMaps() throws Exception {
        StandardWebSocketClient client = new StandardWebSocketClient();
        String wsUrl = "ws://localhost:" + port + "/ws/signaling";

        TestSocketHandler peer1Handler = new TestSocketHandler();
        TestSocketHandler peer2Handler = new TestSocketHandler();

        WebSocketSession peer1Session = client.execute(peer1Handler, wsUrl).get(5, TimeUnit.SECONDS);
        WebSocketSession peer2Session = client.execute(peer2Handler, wsUrl).get(5, TimeUnit.SECONDS);

        String peer1Id = "flutter-device-1";
        String peer2Id = "flutter-device-2";

        WebRTCMessage registerSignal = new WebRTCMessage(
                "REGISTER_CACHE",
                peer1Id,
                null,
                1,
                Set.of(0, 1, 2, 3)
        );
        peer1Session.sendMessage(new TextMessage(objectMapper.writeValueAsString(registerSignal)));

        Map<String, List<Integer>> payloadMap = awaitPeerVisibleViaDiscover(
                peer2Session,
                peer2Handler,
                peer2Id,
                peer1Id,
                Duration.ofSeconds(5)
        );

        List<Integer> peer1Chunks = payloadMap.get(peer1Id);
        assertNotNull(peer1Chunks, "Peer 2 should see Peer 1 in the map");
        assertEquals(4, peer1Chunks.size());
        assertTrue(peer1Chunks.containsAll(List.of(0, 1, 2, 3)));

        peer1Session.close();
        peer2Session.close();
    }

    private Map<String, List<Integer>> awaitPeerVisibleViaDiscover(
            WebSocketSession discoverSession,
            TestSocketHandler discoverHandler,
            String discovererId,
            String expectedPeerId,
            Duration timeout
    ) throws Exception {
        long deadlineNanos = System.nanoTime() + timeout.toNanos();
        TypeReference<Map<String, List<Integer>>> typeRef = new TypeReference<>() {
        };

        while (System.nanoTime() < deadlineNanos) {
            WebRTCMessage discoverSignal = new WebRTCMessage(
                    "DISCOVER_PEERS",
                    discovererId,
                    null,
                    1,
                    null
            );
            discoverSession.sendMessage(new TextMessage(objectMapper.writeValueAsString(discoverSignal)));

            String raw = discoverHandler.nextMessage(500, TimeUnit.MILLISECONDS);
            if (raw == null || raw.isBlank()) {
                continue;
            }

            WebRTCMessage response = objectMapper.readValue(raw, WebRTCMessage.class);
            if (!"PEER_BUFFER_MAP".equals(response.type())) {
                continue;
            }

            Map<String, List<Integer>> payloadMap = objectMapper.convertValue(response.payload(), typeRef);
            if (payloadMap != null && payloadMap.containsKey(expectedPeerId)) {
                return payloadMap;
            }
        }

        fail("Timed out waiting for " + expectedPeerId + " to appear in PEER_BUFFER_MAP");
        return Map.of();
    }

    private static class TestSocketHandler extends TextWebSocketHandler {
        private final BlockingQueue<String> messages = new LinkedBlockingQueue<>();

        @Override
        protected void handleTextMessage(WebSocketSession session, TextMessage message) {
            messages.offer(message.getPayload());
        }

        String nextMessage(long timeout, TimeUnit unit) throws InterruptedException {
            return messages.poll(timeout, unit);
        }
    }
}
