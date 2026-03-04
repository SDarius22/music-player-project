package com.example.musicplayerbackend.integration;

import com.example.musicplayerbackend.data.SongRepository;
import com.example.musicplayerbackend.domain.Song;
import com.example.musicplayerbackend.domain.SongSyncDto;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;
import org.springframework.test.web.servlet.result.MockMvcResultMatchers;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.time.temporal.ChronoUnit;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

@Testcontainers
// This uses MockMvc to exercise the MVC layer without starting a real HTTP server
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.MOCK)
@AutoConfigureMockMvc
class DataSyncIntegrationTest {

    // This single annotation tells Spring to auto-wire the database URL, username, and password
    // directly from this Docker container, completely ignoring your application.yml database settings!
    @Container
    @ServiceConnection
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:latest");

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private SongRepository songRepository;

    private Integer testSongId;

    @BeforeEach
    void setUp() {
        // Clean the database before every test to ensure idempotency
        songRepository.deleteAll();

        // Seed the database directly via the repository
        Song song = new Song();
        song.setName("Integration Test Anthem");
        song.setPath("/tmp/fake_path.mp3");
        song.setPlayCount(10);
        song.setLikedByUser(false);
        song.setLastPlayed(Instant.now().minus(5, ChronoUnit.DAYS));

        song = songRepository.save(song);
        testSongId = song.getId();
    }

    @Test
    void shouldSyncOfflineDataAndPersistToRealDatabase() throws Exception {
        // Arrange: Simulate the Flutter frontend sending a JSON payload
        SongSyncDto syncDto = new SongSyncDto();
        syncDto.setSongId(testSongId);
        syncDto.setPlayCountDelta(4);
        syncDto.setLikedByUser(true);
        syncDto.setLastPlayed(OffsetDateTime.now(ZoneOffset.UTC));

        String json = objectMapper.writeValueAsString(List.of(syncDto));

        // Act: Perform a MockMvc POST to the controller
        mockMvc.perform(
                MockMvcRequestBuilders.post("/api/v1/sync")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json)
        ).andExpect(MockMvcResultMatchers.status().isOk());

        // Assert: Query the real database to ensure the transaction committed successfully
        Song updatedSong = songRepository.findById(testSongId).orElseThrow();
        assertEquals(14, updatedSong.getPlayCount(), "Play count should be 10 (initial) + 4 (delta)");
        assertTrue(updatedSong.getLikedByUser(), "Liked state should be overwritten to true by LWW rule");
    }
}