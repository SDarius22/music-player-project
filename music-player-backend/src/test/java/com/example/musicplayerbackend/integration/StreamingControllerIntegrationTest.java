package com.example.musicplayerbackend.integration;

import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

import com.example.musicplayerbackend.data.ChunkRepository;
import com.example.musicplayerbackend.data.SongChunkRepository;
import com.example.musicplayerbackend.data.SongRepository;
import com.example.musicplayerbackend.data.UserRepository;
import com.example.musicplayerbackend.domain.*;
import java.io.File;
import java.io.FileOutputStream;
import java.nio.file.Path;
import java.util.UUID;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.beans.factory.annotation.Autowired;

class StreamingControllerIntegrationTest extends BaseIntegrationTest {

  @TempDir Path tempDir;

  @Autowired UserRepository userRepository;
  @Autowired SongRepository songRepository;
  @Autowired ChunkRepository chunkRepository;
  @Autowired SongChunkRepository songChunkRepository;

  User testUser;
  User otherUser;
  Song publicSong;
  Song privateSong;

  @BeforeEach
  void setUp() {
    testUser = userRepository.save(buildUser("stream-test@example.com", Role.USER));
    testUser.setAllowed(true);
    testUser = userRepository.save(testUser);
    otherUser = userRepository.save(buildUser("stream-other@example.com", Role.USER));

    publicSong =
        songRepository.save(
            Song.builder()
                .name("Public Stream Song")
                .songType(ContentType.STREAMABLE)
                .fileHash(UUID.randomUUID().toString())
                .build());

    privateSong =
        songRepository.save(
            Song.builder()
                .name("Private Stream Song")
                .songType(ContentType.USER_UPLOAD)
                .ownerId(testUser.getId())
                .fileHash(UUID.randomUUID().toString())
                .build());
  }

  @AfterEach
  void tearDown() {
    songChunkRepository.deleteAll();
    chunkRepository.deleteAll();
    songRepository.deleteAll();
    userRepository.deleteAll();
  }

  @Test
  void shouldReturn200ForPublicSongManifestWithNoChunks() throws Exception {
    mockMvc
        .perform(
            get("/api/v1/stream/{fileHash}/manifest", publicSong.getFileHash())
                .with(user(testUser)))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.fileHash").value(publicSong.getFileHash()))
        .andExpect(jsonPath("$.totalChunks").value(0));
  }

  @Test
  void shouldReturn404WhenManifestPrivateSongOwnedByOther() throws Exception {
    mockMvc
        .perform(
            get("/api/v1/stream/{fileHash}/manifest", privateSong.getFileHash())
                .with(user(otherUser)))
        .andExpect(status().isNotFound());
  }

  @Test
  void shouldReturn200ForManifestWhenPrivateSongOwnedBySelf() throws Exception {
    mockMvc
        .perform(
            get("/api/v1/stream/{fileHash}/manifest", privateSong.getFileHash())
                .with(user(testUser)))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.fileHash").value(privateSong.getFileHash()));
  }

  @Test
  void shouldReturn404WhenManifestSongNotFound() throws Exception {
    mockMvc
        .perform(get("/api/v1/stream/999999/manifest").with(user(testUser)))
        .andExpect(status().isNotFound());
  }

  @Test
  void shouldReturn200WithChunkHashesWhenChunksExist() throws Exception {
    byte[] data = "audio-bytes".getBytes();
    File chunkFile = tempDir.resolve("chunk.bin").toFile();
    try (FileOutputStream fos = new FileOutputStream(chunkFile)) {
      fos.write(data);
    }

    Chunk chunk =
        chunkRepository.save(
            Chunk.builder()
                .contentHash("test-hash-" + UUID.randomUUID())
                .size(data.length)
                .storagePath(chunkFile.getAbsolutePath())
                .build());
    songChunkRepository.save(
        SongChunk.builder().song(publicSong).chunk(chunk).orderIndex(0).build());

    mockMvc
        .perform(
            get("/api/v1/stream/{fileHash}/manifest", publicSong.getFileHash())
                .with(user(testUser)))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.totalChunks").value(1))
        .andExpect(jsonPath("$.hashes").isArray());
  }

  @Test
  void shouldReturn200WhenChunkExists() throws Exception {
    byte[] data = "audio-chunk-data".getBytes();
    File chunkFile = tempDir.resolve("chunk0.bin").toFile();
    try (FileOutputStream fos = new FileOutputStream(chunkFile)) {
      fos.write(data);
    }

    Chunk chunk =
        chunkRepository.save(
            Chunk.builder()
                .contentHash("test-chunk-hash-" + java.util.UUID.randomUUID())
                .size(data.length)
                .storagePath(chunkFile.getAbsolutePath())
                .build());
    songChunkRepository.save(
        SongChunk.builder().song(publicSong).chunk(chunk).orderIndex(0).build());

    mockMvc
        .perform(
            get("/api/v1/stream/{fileHash}/chunk/0", publicSong.getFileHash()).with(user(testUser)))
        .andExpect(status().isOk());
  }

  @Test
  void shouldReturn404WhenChunkAccessIsForbidden() throws Exception {
    mockMvc
        .perform(
            get("/api/v1/stream/{fileHash}/chunk/0", privateSong.getFileHash())
                .with(user(otherUser)))
        .andExpect(status().isNotFound());
  }

  @Test
  void shouldReturn400WhenChunkIndexIsOutOfBounds() throws Exception {
    mockMvc
        .perform(
            get("/api/v1/stream/{fileHash}/chunk/5", publicSong.getFileHash()).with(user(testUser)))
        .andExpect(status().isBadRequest());
  }

  @Test
  void shouldReturn400WhenChunkIndexIsNegative() throws Exception {
    mockMvc
        .perform(
            get("/api/v1/stream/{fileHash}/chunk/-1", publicSong.getFileHash())
                .with(user(testUser)))
        .andExpect(status().isBadRequest());
  }
}
