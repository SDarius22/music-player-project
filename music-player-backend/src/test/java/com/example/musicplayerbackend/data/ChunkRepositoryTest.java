package com.example.musicplayerbackend.data;

import static org.assertj.core.api.Assertions.assertThat;

import com.example.musicplayerbackend.domain.Chunk;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

class ChunkRepositoryTest extends BaseRepositoryTest {

  @Autowired ChunkRepository chunkRepository;

  @AfterEach
  void tearDown() {
    chunkRepository.deleteAll();
  }

  private Chunk buildChunk(String hash) {
    return Chunk.builder()
        .contentHash(hash)
        .size(65536)
        .storagePath("/chunks/" + hash + ".bin")
        .build();
  }

  @Test
  void shouldPersistChunk() {
    Chunk saved = chunkRepository.save(buildChunk("abc123"));

    assertThat(saved.getId()).isNotNull().isPositive();
    assertThat(saved.getContentHash()).isEqualTo("abc123");
    assertThat(saved.getSize()).isEqualTo(65536);
  }

  @Test
  void shouldReturnChunkWhenContentHashExists() {
    chunkRepository.save(buildChunk("deadbeef01234567"));

    var found = chunkRepository.findByContentHash("deadbeef01234567");

    assertThat(found).isPresent();
    assertThat(found.get().getStoragePath()).isEqualTo("/chunks/deadbeef01234567.bin");
  }

  @Test
  void shouldReturnEmptyWhenContentHashNotFound() {
    var found = chunkRepository.findByContentHash("nonexistent");

    assertThat(found).isEmpty();
  }

  @Test
  void shouldNotReturnChunkWithDifferentContentHash() {
    chunkRepository.save(buildChunk("hash-a"));
    chunkRepository.save(buildChunk("hash-b"));

    var found = chunkRepository.findByContentHash("hash-a");

    assertThat(found).isPresent();
    assertThat(found.get().getContentHash()).isEqualTo("hash-a");
  }

  @Test
  void shouldRemoveChunkWhenDeletedById() {
    Chunk saved = chunkRepository.save(buildChunk("todelete"));
    chunkRepository.deleteById(saved.getId());

    assertThat(chunkRepository.findByContentHash("todelete")).isEmpty();
  }
}
