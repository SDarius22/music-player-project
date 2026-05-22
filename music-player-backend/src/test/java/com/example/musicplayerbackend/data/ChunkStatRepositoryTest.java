package com.example.musicplayerbackend.data;

import static org.assertj.core.api.Assertions.assertThat;

import com.example.musicplayerbackend.domain.ChunkStat;
import com.example.musicplayerbackend.domain.User;
import java.time.Instant;
import java.util.List;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

class ChunkStatRepositoryTest extends BaseRepositoryTest {

  @Autowired ChunkStatRepository chunkStatRepository;

  @Autowired UserRepository userRepository;

  @AfterEach
  void tearDown() {
    chunkStatRepository.deleteAll();
    userRepository.deleteAll();
  }

  private ChunkStat buildStat(int p2p, int server, int total) {
    double percentage = total > 0 ? (double) p2p / total * 100.0 : 0.0;
    return ChunkStat.builder()
        .timestamp(Instant.now())
        .localChunks(0)
        .localCachedChunks(0)
        .p2pChunks(p2p)
        .serverChunks(server)
        .totalChunks(total)
        .p2pPercentage(percentage)
        .build();
  }

  @Test
  void shouldPersistStat() {
    ChunkStat saved = chunkStatRepository.save(buildStat(8, 2, 10));

    assertThat(saved.getId()).isNotNull().isPositive();
    assertThat(saved.getP2pChunks()).isEqualTo(8);
    assertThat(saved.getServerChunks()).isEqualTo(2);
    assertThat(saved.getTotalChunks()).isEqualTo(10);
    assertThat(saved.getP2pPercentage()).isEqualTo(80.0);
  }

  @Test
  void shouldReturnAllPersistedStats() {
    chunkStatRepository.save(buildStat(5, 5, 10));
    chunkStatRepository.save(buildStat(0, 10, 10));
    chunkStatRepository.save(buildStat(10, 0, 10));

    List<ChunkStat> all = chunkStatRepository.findAll();

    assertThat(all).hasSize(3);
  }

  @Test
  void shouldPersistStatWithUserAndSongContext() {
    User user = userRepository.save(buildUser("chunkstat@example.com"));

    ChunkStat saved =
        ChunkStat.builder()
            .timestamp(Instant.now())
            .userId(user.getId())
            .songFileHash("hash-100")
            .songName("Bohemian Rhapsody")
            .localChunks(0)
            .localCachedChunks(0)
            .p2pChunks(3)
            .serverChunks(7)
            .totalChunks(10)
            .p2pPercentage(30.0)
            .build();

    ChunkStat result = chunkStatRepository.save(saved);

    assertThat(result.getUserId()).isEqualTo(user.getId());
    assertThat(result.getSongFileHash()).isEqualTo("hash-100");
    assertThat(result.getSongName()).isEqualTo("Bohemian Rhapsody");
  }

  @Test
  void shouldRemoveStatEntryWhenDeletedById() {
    ChunkStat saved = chunkStatRepository.save(buildStat(1, 1, 2));
    chunkStatRepository.deleteById(saved.getId());

    assertThat(chunkStatRepository.findById(saved.getId())).isEmpty();
  }

  @Test
  void shouldReflectCorrectNumberOfStats() {
    assertThat(chunkStatRepository.count()).isZero();
    chunkStatRepository.save(buildStat(1, 9, 10));
    chunkStatRepository.save(buildStat(2, 8, 10));
    assertThat(chunkStatRepository.count()).isEqualTo(2);
  }
}
