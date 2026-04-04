package com.example.musicplayerbackend.integration;

import com.example.musicplayerbackend.components.SignalingHandler;
import com.example.musicplayerbackend.data.UserPlaybackStateRepository;
import com.example.musicplayerbackend.data.UserRepository;
import com.example.musicplayerbackend.domain.AuthProvider;
import com.example.musicplayerbackend.domain.PlaybackStateDto;
import com.example.musicplayerbackend.domain.Role;
import com.example.musicplayerbackend.domain.User;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import java.time.Instant;
import java.util.List;

import static org.hamcrest.Matchers.hasSize;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@Testcontainers
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.MOCK, properties = {
        "MAIL_HOST=localhost", "MAIL_USER=test@example.com", "MAIL_PASSWORD=test"
})
@AutoConfigureMockMvc
class PlaybackStateIntegrationTest {

    @Container
    @ServiceConnection
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:latest");

    // Redis is required by RedisMessageListenerContainer at startup.
    @Container
    @SuppressWarnings("resource")
    static GenericContainer<?> redis =
            new GenericContainer<>("redis:7-alpine").withExposedPorts(6379);
    @Autowired
    MockMvc mockMvc;
    @Autowired
    ObjectMapper objectMapper;
    @Autowired
    UserRepository userRepository;
    @Autowired
    UserPlaybackStateRepository playbackStateRepository;
    /**
     * Mock out the SignalingHandler so the saveState flow never actually publishes
     * to Redis pub/sub during these tests (avoids flaky failures from network-level
     * pub/sub timing and keeps assertions focused on REST behaviour).
     */
    @MockitoBean
    SignalingHandler signalingHandler;
    private User testUser;

    @DynamicPropertySource
    static void redisProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.data.redis.host", redis::getHost);
        registry.add("spring.data.redis.port", () -> redis.getMappedPort(6379));
    }

    @BeforeEach
    void setUp() {
        testUser = userRepository.save(User.builder()
                .email("playback-test@example.com")
                .role(Role.USER)
                .provider(AuthProvider.LOCAL)
                .createdAt(Instant.now())
                .build());
    }

    @AfterEach
    void tearDown() {
        // Cascade on user_id FK removes the playback state row automatically,
        // but delete explicitly to be safe with FK ordering.
        playbackStateRepository.deleteAll();
        userRepository.deleteAll();
    }

    // ── GET /api/v1/playback ─────────────────────────────────────────────────

    @Test
    void shouldReturn204WhenNoPlaybackStateHasBeenSavedYet() throws Exception {
        mockMvc.perform(get("/api/v1/playback").with(user(testUser)))
                .andExpect(status().isNoContent());
    }

    // ── PUT then GET ─────────────────────────────────────────────────────────

    @Test
    void shouldPersistAllFieldsInPutThenGetRoundTrip() throws Exception {
        PlaybackStateDto dto = new PlaybackStateDto();
        dto.setQueueFileHashes(List.of("hash-10", "hash-20", "hash-30"));
        // currentSongId left null to avoid FK constraint against songs table
        dto.setPositionMs(45_000L);
        dto.setShuffle(true);
        dto.setRepeat(false);

        // PUT — should return the persisted state
        mockMvc.perform(put("/api/v1/playback")
                        .with(user(testUser))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(dto)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.positionMs").value(45_000))
                .andExpect(jsonPath("$.shuffle").value(true))
                .andExpect(jsonPath("$.repeat").value(false))
                .andExpect(jsonPath("$.updatedAt").isNotEmpty());

        // GET — same values come back
        mockMvc.perform(get("/api/v1/playback").with(user(testUser)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.queueFileHashes", hasSize(3)))
                .andExpect(jsonPath("$.positionMs").value(45_000))
                .andExpect(jsonPath("$.shuffle").value(true))
                .andExpect(jsonPath("$.repeat").value(false));
    }

    @Test
    void shouldOverwritePreviousPlaybackStateOnSecondPut() throws Exception {
        PlaybackStateDto first = new PlaybackStateDto();
        first.setQueueFileHashes(List.of("hash-1", "hash-2"));
        first.setShuffle(false);
        first.setRepeat(false);
        first.setPositionMs(1_000L);

        mockMvc.perform(put("/api/v1/playback")
                        .with(user(testUser))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(first)))
                .andExpect(status().isOk());

        PlaybackStateDto second = new PlaybackStateDto();
        second.setQueueFileHashes(List.of("hash-5"));
        second.setShuffle(true);
        second.setRepeat(true);
        second.setPositionMs(9_999L);

        mockMvc.perform(put("/api/v1/playback")
                        .with(user(testUser))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(second)))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/v1/playback").with(user(testUser)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.queueFileHashes", hasSize(1)))
                .andExpect(jsonPath("$.positionMs").value(9_999))
                .andExpect(jsonPath("$.shuffle").value(true))
                .andExpect(jsonPath("$.repeat").value(true));
    }
}
