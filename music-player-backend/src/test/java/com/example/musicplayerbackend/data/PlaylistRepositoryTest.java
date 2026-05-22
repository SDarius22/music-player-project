package com.example.musicplayerbackend.data;

import static org.assertj.core.api.Assertions.assertThat;

import com.example.musicplayerbackend.data.projection.PlaylistListProjection;
import com.example.musicplayerbackend.domain.Playlist;
import com.example.musicplayerbackend.domain.User;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;

class PlaylistRepositoryTest extends BaseRepositoryTest {

  @Autowired PlaylistRepository playlistRepository;

  @Autowired UserRepository userRepository;

  private User userA;
  private User userB;

  @BeforeEach
  void setUp() {
    userA = userRepository.save(buildUser("playlist-a@example.com"));
    userB = userRepository.save(buildUser("playlist-b@example.com"));
  }

  @AfterEach
  void tearDown() {
    playlistRepository.deleteAll();
    userRepository.deleteAll();
  }

  private Playlist buildPlaylist(User owner, String name) {
    return Playlist.builder().user(owner).name(name).build();
  }

  @Test
  void shouldPersistPlaylist() {
    Playlist saved = playlistRepository.save(buildPlaylist(userA, "Chill Vibes"));

    assertThat(saved.getId()).isNotNull().isPositive();
    assertThat(saved.getName()).isEqualTo("Chill Vibes");
  }

  @Test
  void shouldReturnPlaylistsForUser() {
    playlistRepository.save(buildPlaylist(userA, "Playlist A1"));
    playlistRepository.save(buildPlaylist(userA, "Playlist A2"));
    playlistRepository.save(buildPlaylist(userB, "Playlist B1"));

    Page<PlaylistListProjection> result =
        playlistRepository.findAllWithHashes(userA.getId(), "", null, PageRequest.of(0, 10));

    assertThat(result.getContent())
        .hasSize(2)
        .extracting(PlaylistListProjection::getName)
        .containsExactlyInAnyOrder("Playlist A1", "Playlist A2");
  }

  @Test
  void shouldNotReturnOtherUsersPlaylists() {
    playlistRepository.save(buildPlaylist(userA, "Only A's"));
    playlistRepository.save(buildPlaylist(userB, "Only B's"));

    Page<PlaylistListProjection> result =
        playlistRepository.findAllWithHashes(userA.getId(), "", null, PageRequest.of(0, 10));

    assertThat(result.getContent())
        .extracting(PlaylistListProjection::getName)
        .doesNotContain("Only B's");
  }

  @Test
  void shouldReturnEmptyPageWhenUserHasNoPlaylists() {
    Page<PlaylistListProjection> result =
        playlistRepository.findAllWithHashes(userA.getId(), "", null, PageRequest.of(0, 10));

    assertThat(result).isEmpty();
  }

  @Test
  void shouldRespectPaginationWhenFetchingPlaylistsByUserId() {
    for (int i = 0; i < 5; i++) {
      playlistRepository.save(buildPlaylist(userA, "Playlist " + i));
    }

    Page<PlaylistListProjection> page0 =
        playlistRepository.findAllWithHashes(userA.getId(), "", null, PageRequest.of(0, 2));
    Page<PlaylistListProjection> page1 =
        playlistRepository.findAllWithHashes(userA.getId(), "", null, PageRequest.of(1, 2));

    assertThat(page0.getContent()).hasSize(2);
    assertThat(page0.getTotalElements()).isEqualTo(5);
    assertThat(page1.getContent()).hasSize(2);
  }

  @Test
  void shouldRemovePlaylistWhenDeleted() {
    Playlist saved = playlistRepository.save(buildPlaylist(userA, "ToDelete"));
    playlistRepository.delete(saved);

    Page<PlaylistListProjection> result =
        playlistRepository.findAllWithHashes(userA.getId(), "", null, PageRequest.of(0, 10));
    assertThat(result).isEmpty();
  }
}
