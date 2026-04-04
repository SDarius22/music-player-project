package com.example.musicplayerbackend.integration;

import com.example.musicplayerbackend.data.ChunkStatRepository;
import com.example.musicplayerbackend.data.UserRepository;
import com.example.musicplayerbackend.domain.*;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;

import static org.hamcrest.Matchers.*;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

class StatisticsControllerIntegrationTest extends BaseIntegrationTest {

    @Autowired ChunkStatRepository chunkStatRepository;
    @Autowired UserRepository userRepository;
    @Autowired ObjectMapper objectMapper;

    User testUser;
    User adminUser;

    @BeforeEach
    void setUp() {
        testUser = userRepository.save(buildUser("stats-test@example.com", Role.USER));
        adminUser = userRepository.save(buildUser("stats-admin@example.com", Role.ADMIN));
    }

    @AfterEach
    void tearDown() {
        chunkStatRepository.deleteAll();
        userRepository.deleteById(testUser.getId());
        userRepository.deleteById(adminUser.getId());
    }

    @Test
    void shouldReturn200WithEmptyStatisticsList() throws Exception {
        // GET /statistics requires ADMIN role
        mockMvc.perform(get("/api/v1/statistics").with(user(adminUser)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", instanceOf(java.util.List.class)));
    }

    @Test
    void shouldReturn201AndPersistStatistic() throws Exception {
        ChunkStatDto dto = new ChunkStatDto();
        dto.setSongFileHash("hash-1");
        dto.setSongName("Test Song");
        dto.setP2pChunks(8);
        dto.setServerChunks(2);

        mockMvc.perform(post("/api/v1/statistics")
                        .with(user(testUser))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(dto)))
                .andExpect(status().isCreated());

        // Verify persisted (GET requires ADMIN)
        mockMvc.perform(get("/api/v1/statistics").with(user(adminUser)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", not(empty())))
                .andExpect(jsonPath("$[0].songName").value("Test Song"))
                .andExpect(jsonPath("$[0].p2pPercentage").value(80.0));
    }

    @Test
    void shouldHandleNullChunksWhenSubmittingStatistic() throws Exception {
        ChunkStatDto dto = new ChunkStatDto();
        dto.setSongFileHash("hash-1");
        dto.setSongName("Null Chunks");

        mockMvc.perform(post("/api/v1/statistics")
                        .with(user(testUser))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(dto)))
                .andExpect(status().isCreated());
    }

    @Test
    void shouldReturnMultipleStatisticRecords() throws Exception {
        // Submit two stats
        for (int i = 0; i < 2; i++) {
            ChunkStatDto dto = new ChunkStatDto();
            dto.setSongFileHash("hash-" + i);
            dto.setSongName("Song " + i);
            dto.setP2pChunks(5);
            dto.setServerChunks(5);
            mockMvc.perform(post("/api/v1/statistics")
                            .with(user(testUser))
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(objectMapper.writeValueAsString(dto)))
                    .andExpect(status().isCreated());
        }

        mockMvc.perform(get("/api/v1/statistics").with(user(adminUser)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(greaterThanOrEqualTo(2))));
    }
}
