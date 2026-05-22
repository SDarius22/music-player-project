package com.example.musicplayerbackend.data;

import static org.assertj.core.api.Assertions.assertThat;

import com.example.musicplayerbackend.domain.*;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;

class UserLibraryRepositoryTest extends BaseRepositoryTest {

  @Autowired UserLibraryRepository userLibraryRepository;

  @Autowired UserRepository userRepository;

  @Autowired SongRepository songRepository;

  @Autowired ArtistRepository artistRepository;

  @Autowired AlbumRepository albumRepository;

  private User user;
  private Song song1;
  private Song song2;
  private Song song3;

  @BeforeEach
  void setUp() {
    user = userRepository.save(buildUser("library@example.com"));
    Artist artist = artistRepository.save(Artist.builder().name("Artist").build());
    Album album =
        albumRepository.save(Album.builder().name("Album").artists(Set.of(artist)).build());

    song1 =
        songRepository.save(
            Song.builder()
                .name("Song 1")
                .artist(artist)
                .album(album)
                .songType(ContentType.STREAMABLE)
                .fileHash(UUID.randomUUID().toString())
                .build());
    song2 =
        songRepository.save(
            Song.builder()
                .name("Song 2")
                .artist(artist)
                .album(album)
                .songType(ContentType.STREAMABLE)
                .fileHash(UUID.randomUUID().toString())
                .build());
    song3 =
        songRepository.save(
            Song.builder()
                .name("Song 3")
                .artist(artist)
                .album(album)
                .songType(ContentType.STREAMABLE)
                .fileHash(UUID.randomUUID().toString())
                .build());
  }

  @AfterEach
  void tearDown() {
    userLibraryRepository.deleteAll();
    songRepository.deleteAll();
    albumRepository.deleteAll();
    artistRepository.deleteAll();
    userRepository.deleteAll();
  }

  private UserLibrary buildEntry(
      User u,
      Song s,
      boolean liked,
      long playCount,
      Instant lastPlayed,
      Instant addedAt,
      boolean deleted) {
    UserLibraryID id = new UserLibraryID(u.getId(), s.getId());
    return UserLibrary.builder()
        .id(id)
        .user(u)
        .song(s)
        .liked(liked)
        .playCount(playCount)
        .lastPlayed(lastPlayed)
        .addedAt(addedAt)
        .lastUpdated(Instant.now())
        .isDeleted(deleted)
        .build();
  }

  @Test
  void shouldReturnOnlyRecentEntriesAfterLastUpdated() {
    Instant boundary = Instant.now().minus(1, ChronoUnit.HOURS);

    UserLibrary old =
        buildEntry(user, song1, false, 0, null, Instant.now().minus(2, ChronoUnit.HOURS), false);
    old.setLastUpdated(Instant.now().minus(2, ChronoUnit.HOURS));
    userLibraryRepository.save(old);

    userLibraryRepository.save(buildEntry(user, song2, false, 0, null, Instant.now(), false));

    List<UserLibrary> result =
        userLibraryRepository.findByIdUserIdAndLastUpdatedAfter(user.getId(), boundary);

    assertThat(result).hasSize(1);
    assertThat(result.getFirst().getId().getSongId()).isEqualTo(song2.getId());
  }

  @Test
  void shouldReturnEmptyWhenAllLibraryEntriesAreOlderThanBoundary() {
    Instant boundary = Instant.now().plus(1, ChronoUnit.HOURS);

    UserLibrary old = buildEntry(user, song1, false, 0, null, Instant.now(), false);
    old.setLastUpdated(Instant.now().minus(2, ChronoUnit.HOURS));
    userLibraryRepository.save(old);

    List<UserLibrary> result =
        userLibraryRepository.findByIdUserIdAndLastUpdatedAfter(user.getId(), boundary);

    assertThat(result).isEmpty();
  }

  @Test
  void shouldExcludeDeletedEntriesFromLibrary() {
    userLibraryRepository.save(buildEntry(user, song1, false, 1, null, Instant.now(), false));
    userLibraryRepository.save(buildEntry(user, song2, false, 1, null, Instant.now(), true));

    List<UserLibrary> result = userLibraryRepository.findByIdUserIdAndIsDeletedFalse(user.getId());

    assertThat(result).hasSize(1);
    assertThat(result.getFirst().getId().getSongId()).isEqualTo(song1.getId());
  }

  @Test
  void shouldReturnEmptyWhenAllLibraryEntriesAreDeleted() {
    userLibraryRepository.save(buildEntry(user, song1, false, 1, null, Instant.now(), true));
    userLibraryRepository.save(buildEntry(user, song2, false, 1, null, Instant.now(), true));

    List<UserLibrary> result = userLibraryRepository.findByIdUserIdAndIsDeletedFalse(user.getId());

    assertThat(result).isEmpty();
  }

  @Test
  void shouldExcludeOtherUsersLibraryEntries() {
    User otherUser = userRepository.save(buildUser("other-library@example.com"));
    userLibraryRepository.save(buildEntry(otherUser, song1, false, 1, null, Instant.now(), false));
    userLibraryRepository.save(buildEntry(user, song2, false, 1, null, Instant.now(), false));

    List<UserLibrary> result = userLibraryRepository.findByIdUserIdAndIsDeletedFalse(user.getId());

    assertThat(result).hasSize(1);
    assertThat(result.getFirst().getId().getSongId()).isEqualTo(song2.getId());
  }

  @Test
  void shouldReturnOnlyLikedAndNotDeletedOrderedByPlayCountDesc() {
    userLibraryRepository.save(buildEntry(user, song1, true, 10, null, Instant.now(), false));
    userLibraryRepository.save(buildEntry(user, song2, true, 50, null, Instant.now(), false));
    userLibraryRepository.save(buildEntry(user, song3, false, 99, null, Instant.now(), false));

    Page<UserLibrary> result =
        userLibraryRepository.findLikedByUserId(user.getId(), PageRequest.of(0, 10));

    assertThat(result.getContent()).hasSize(2);
    assertThat(result.getContent().get(0).getPlayCount()).isEqualTo(50);
    assertThat(result.getContent().get(1).getPlayCount()).isEqualTo(10);
  }

  @Test
  void shouldExcludeDeletedFromLikedSongs() {
    userLibraryRepository.save(buildEntry(user, song1, true, 5, null, Instant.now(), true));

    Page<UserLibrary> result =
        userLibraryRepository.findLikedByUserId(user.getId(), PageRequest.of(0, 10));

    assertThat(result.getContent()).isEmpty();
  }

  @Test
  void shouldReturnEmptyWhenNoLikedSongs() {
    userLibraryRepository.save(buildEntry(user, song1, false, 5, null, Instant.now(), false));

    Page<UserLibrary> result =
        userLibraryRepository.findLikedByUserId(user.getId(), PageRequest.of(0, 10));

    assertThat(result.getContent()).isEmpty();
  }

  @Test
  void shouldReturnMostPlayedOrderedByPlayCountDescExcludingZero() {
    userLibraryRepository.save(buildEntry(user, song1, false, 5, null, Instant.now(), false));
    userLibraryRepository.save(buildEntry(user, song2, false, 20, null, Instant.now(), false));
    userLibraryRepository.save(buildEntry(user, song3, false, 0, null, Instant.now(), false));

    Page<UserLibrary> result =
        userLibraryRepository.findMostPlayedByUserId(user.getId(), PageRequest.of(0, 10));

    assertThat(result.getContent()).hasSize(2);
    assertThat(result.getContent().get(0).getPlayCount()).isEqualTo(20);
    assertThat(result.getContent().get(1).getPlayCount()).isEqualTo(5);
  }

  @Test
  void shouldReturnEmptyWhenAllPlayCountIsZero() {
    userLibraryRepository.save(buildEntry(user, song1, false, 0, null, Instant.now(), false));
    userLibraryRepository.save(buildEntry(user, song2, false, 0, null, Instant.now(), false));

    Page<UserLibrary> result =
        userLibraryRepository.findMostPlayedByUserId(user.getId(), PageRequest.of(0, 10));

    assertThat(result.getContent()).isEmpty();
  }

  @Test
  void shouldReturnOnlyEntriesPlayedBeforeCutoff() {
    Instant cutoff = Instant.now().minus(30, ChronoUnit.DAYS);
    Instant oldPlay = Instant.now().minus(60, ChronoUnit.DAYS);
    Instant recentPlay = Instant.now();

    userLibraryRepository.save(buildEntry(user, song1, false, 3, oldPlay, Instant.now(), false));
    userLibraryRepository.save(buildEntry(user, song2, false, 3, recentPlay, Instant.now(), false));

    Page<UserLibrary> result =
        userLibraryRepository.findForgottenByUserId(user.getId(), cutoff, PageRequest.of(0, 10));

    assertThat(result.getContent()).hasSize(1);
    assertThat(result.getContent().getFirst().getId().getSongId()).isEqualTo(song1.getId());
  }

  @Test
  void shouldExcludeForgottenEntriesWithNoPlayCount() {
    Instant cutoff = Instant.now().minus(30, ChronoUnit.DAYS);
    Instant oldPlay = Instant.now().minus(60, ChronoUnit.DAYS);

    userLibraryRepository.save(buildEntry(user, song1, false, 0, oldPlay, Instant.now(), false));

    Page<UserLibrary> result =
        userLibraryRepository.findForgottenByUserId(user.getId(), cutoff, PageRequest.of(0, 10));

    assertThat(result.getContent()).isEmpty();
  }

  @Test
  void shouldExcludeForgottenEntriesWithNullLastPlayed() {
    Instant cutoff = Instant.now().minus(30, ChronoUnit.DAYS);
    userLibraryRepository.save(buildEntry(user, song1, false, 3, null, Instant.now(), false));

    Page<UserLibrary> result =
        userLibraryRepository.findForgottenByUserId(user.getId(), cutoff, PageRequest.of(0, 10));

    assertThat(result.getContent()).isEmpty();
  }

  @Test
  void shouldExcludeOtherUsersForgottenEntries() {
    User otherUser = userRepository.save(buildUser("forgotten-other@example.com"));
    Instant cutoff = Instant.now().minus(30, ChronoUnit.DAYS);
    Instant oldPlay = Instant.now().minus(60, ChronoUnit.DAYS);
    userLibraryRepository.save(
        buildEntry(otherUser, song1, false, 5, oldPlay, Instant.now(), false));

    Page<UserLibrary> result =
        userLibraryRepository.findForgottenByUserId(user.getId(), cutoff, PageRequest.of(0, 10));

    assertThat(result.getContent()).isEmpty();
  }

  @Test
  void shouldReturnRecentlyAddedOrderedByAddedAtDesc() {
    Instant t1 = Instant.now().minus(10, ChronoUnit.DAYS);
    Instant t2 = Instant.now().minus(1, ChronoUnit.DAYS);

    userLibraryRepository.save(buildEntry(user, song1, false, 0, null, t1, false));
    userLibraryRepository.save(buildEntry(user, song2, false, 0, null, t2, false));

    Page<UserLibrary> result =
        userLibraryRepository.findRecentlyAddedByUserId(user.getId(), PageRequest.of(0, 10));

    assertThat(result.getContent()).hasSize(2);
    assertThat(result.getContent().get(0).getId().getSongId()).isEqualTo(song2.getId());
  }

  @Test
  void shouldReturnEmptyWhenNoRecentlyAddedEntries() {
    Page<UserLibrary> result =
        userLibraryRepository.findRecentlyAddedByUserId(user.getId(), PageRequest.of(0, 10));

    assertThat(result.getContent()).isEmpty();
  }

  @Test
  void shouldExcludeOtherUsersRecentlyAddedEntries() {
    User otherUser = userRepository.save(buildUser("recently-added-other@example.com"));
    userLibraryRepository.save(buildEntry(otherUser, song1, false, 0, null, Instant.now(), false));

    Page<UserLibrary> result =
        userLibraryRepository.findRecentlyAddedByUserId(user.getId(), PageRequest.of(0, 10));

    assertThat(result.getContent()).isEmpty();
  }

  @Test
  void shouldReturnRecentlyPlayedOrderedByLastPlayedDescExcludingNeverPlayed() {
    Instant playedLong = Instant.now().minus(5, ChronoUnit.DAYS);
    Instant playedRecent = Instant.now().minus(1, ChronoUnit.HOURS);

    userLibraryRepository.save(buildEntry(user, song1, false, 1, playedLong, Instant.now(), false));
    userLibraryRepository.save(
        buildEntry(user, song2, false, 1, playedRecent, Instant.now(), false));
    userLibraryRepository.save(buildEntry(user, song3, false, 0, null, Instant.now(), false));

    Page<UserLibrary> result =
        userLibraryRepository.findRecentlyPlayedByUserId(user.getId(), PageRequest.of(0, 10));

    assertThat(result.getContent()).hasSize(2);
    assertThat(result.getContent().get(0).getId().getSongId()).isEqualTo(song2.getId());
    assertThat(result.getContent().get(1).getId().getSongId()).isEqualTo(song1.getId());
  }

  @Test
  void shouldReturnEmptyWhenNothingPlayed() {
    userLibraryRepository.save(buildEntry(user, song1, false, 0, null, Instant.now(), false));

    Page<UserLibrary> result =
        userLibraryRepository.findRecentlyPlayedByUserId(user.getId(), PageRequest.of(0, 10));

    assertThat(result.getContent()).isEmpty();
  }

  @Test
  void shouldExcludeOtherUsersRecentlyPlayedEntries() {
    User otherUser = userRepository.save(buildUser("played-other@example.com"));
    Instant played = Instant.now().minus(1, ChronoUnit.HOURS);
    userLibraryRepository.save(
        buildEntry(otherUser, song1, false, 1, played, Instant.now(), false));

    Page<UserLibrary> result =
        userLibraryRepository.findRecentlyPlayedByUserId(user.getId(), PageRequest.of(0, 10));

    assertThat(result.getContent()).isEmpty();
  }
}
