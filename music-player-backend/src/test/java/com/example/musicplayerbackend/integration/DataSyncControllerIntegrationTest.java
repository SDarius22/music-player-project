package com.example.musicplayerbackend.integration;

import com.example.musicplayerbackend.data.SongRepository;
import com.example.musicplayerbackend.data.UserLibraryRepository;
import com.example.musicplayerbackend.data.UserRepository;
import com.example.musicplayerbackend.domain.*;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;

import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;
import java.util.UUID;

import static org.hamcrest.Matchers.*;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

class DataSyncControllerIntegrationTest extends BaseIntegrationTest {

    @Autowired UserRepository userRepository;
    @Autowired SongRepository songRepository;
    @Autowired UserLibraryRepository userLibraryRepository;
    @Autowired ObjectMapper objectMapper;

    User testUser;
    Song testSong;

    @BeforeEach
    void setUp() {
        testUser = userRepository.save(buildUser("sync-test@example.com", Role.USER));
        testSong = songRepository.save(Song.builder()
                .name("Sync Test Song")
                .songType(ContentType.STREAMABLE)
                .fileHash(UUID.randomUUID().toString())
                .build());
    }

    @AfterEach
    void tearDown() {
        userLibraryRepository.deleteAll();
        songRepository.deleteAll();
        userRepository.deleteById(testUser.getId());
    }

    @Test
    void shouldReturn200WithEmptySyncRequest() throws Exception {
        SyncRequestDto req = new SyncRequestDto();

        mockMvc.perform(post("/api/v1/sync")
                        .with(user(testUser))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.newSyncTime").isNotEmpty())
                .andExpect(jsonPath("$.serverChanges").isArray());
    }

    @Test
    void shouldReturnLibraryEntriesWhenNoLastSyncTime() throws Exception {
        UserLibrary entry = UserLibrary.builder()
                .id(new UserLibraryID(testUser.getId(), testSong.getId()))
                .user(testUser).song(testSong)
                .liked(true).playCount(3L).isDeleted(false)
                .lastUpdated(Instant.now()).build();
        userLibraryRepository.save(entry);

        SyncRequestDto req = new SyncRequestDto();

        mockMvc.perform(post("/api/v1/sync")
                        .with(user(testUser))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.serverChanges", hasSize(greaterThanOrEqualTo(1))))
                .andExpect(jsonPath("$.serverChanges[0].fileHash").value(testSong.getFileHash()));
    }

    @Test
    void shouldReturnOnlyUpdatedEntriesWhenLastSyncTimeIsSet() throws Exception {
        UserLibrary entry = UserLibrary.builder()
                .id(new UserLibraryID(testUser.getId(), testSong.getId()))
                .user(testUser).song(testSong)
                .liked(false).playCount(1L).isDeleted(false)
                .lastUpdated(Instant.now()).build();
        userLibraryRepository.save(entry);

        // lastSyncTime = 1 minute in future → nothing updated after that
        SyncRequestDto req = new SyncRequestDto();
        req.setLastSyncTime(OffsetDateTime.now(ZoneOffset.UTC).plusMinutes(1));

        mockMvc.perform(post("/api/v1/sync")
                        .with(user(testUser))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.serverChanges", empty()));
    }

    @Test
    void shouldApplyLocalChangesAndPersist() throws Exception {
        SongSyncDto change = new SongSyncDto();
        change.setFileHash(testSong.getFileHash());
        change.setLikedByUser(true);
        change.setIsDeleted(false);

        SyncRequestDto req = new SyncRequestDto();
        req.setLocalChanges(List.of(change));

        mockMvc.perform(post("/api/v1/sync")
                        .with(user(testUser))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isOk());

        // Verify persisted by syncing again with no lastSyncTime
        SyncRequestDto verify = new SyncRequestDto();
        mockMvc.perform(post("/api/v1/sync")
                        .with(user(testUser))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(verify)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.serverChanges[?(@.fileHash == '" + testSong.getFileHash() + "')].likedByUser",
                        contains(true)));
    }

    @Test
    void shouldReturn403WhenSyncRequestIsUnauthenticated() throws Exception {
        SyncRequestDto req = new SyncRequestDto();

        // Spring Security stateless config returns 403 (not 401) for unauthenticated requests
        mockMvc.perform(post("/api/v1/sync")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isForbidden());
    }
}
