package com.example.musicplayerbackend.data;

import static org.assertj.core.api.Assertions.assertThat;

import com.example.musicplayerbackend.domain.Album;
import com.example.musicplayerbackend.domain.Artist;
import java.util.Set;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.transaction.annotation.Transactional;

class AlbumRepositoryTest extends BaseRepositoryTest {

  @Autowired AlbumRepository albumRepository;

  @Autowired ArtistRepository artistRepository;

  private Artist artist;

  @BeforeEach
  void setUp() {
    artist =
        artistRepository.save(Artist.builder().name("Test Artist").hash("artist-hash").build());
  }

  @AfterEach
  void tearDown() {
    albumRepository.deleteAll();
    artistRepository.deleteAll();
  }

  private Album buildAlbum(String name) {
    return Album.builder().name(name).hash("album-" + name).artists(Set.of(artist)).build();
  }

  @Test
  void shouldPersistAlbum() {
    Album saved = albumRepository.save(buildAlbum("Dark Side"));

    assertThat(saved.getId()).isNotNull().isPositive();
    assertThat(saved.getName()).isEqualTo("Dark Side");
  }

  @Test
  void shouldReturnAlbumWhenHashExists() {
    Album album = buildAlbum("Rumours");
    albumRepository.save(album);

    var found = albumRepository.findByHash(album.getHash());

    assertThat(found).isPresent();
    assertThat(found.get().getName()).isEqualTo("Rumours");
  }

  @Test
  void shouldReturnEmptyWhenAlbumHashNotFound() {
    var found = albumRepository.findByHash("missing-hash");

    assertThat(found).isEmpty();
  }

  @Test
  void shouldMatchSubstringWhenSearchingByNameIgnoreCase() {
    albumRepository.save(buildAlbum("Abbey Road"));
    albumRepository.save(buildAlbum("Abbey One"));
    albumRepository.save(buildAlbum("Unrelated"));

    Page<Album> result =
        albumRepository.findAllByNameContainingIgnoreCase("abbey", PageRequest.of(0, 10));

    assertThat(result.getContent())
        .hasSize(2)
        .extracting(Album::getName)
        .containsExactlyInAnyOrder("Abbey Road", "Abbey One");
  }

  @Test
  void shouldBeCaseInsensitiveWhenSearchingByName() {
    albumRepository.save(buildAlbum("Thriller"));

    Page<Album> lower =
        albumRepository.findAllByNameContainingIgnoreCase("thriller", PageRequest.of(0, 10));
    Page<Album> upper =
        albumRepository.findAllByNameContainingIgnoreCase("THRILLER", PageRequest.of(0, 10));
    Page<Album> mixed =
        albumRepository.findAllByNameContainingIgnoreCase("ThRiLlEr", PageRequest.of(0, 10));

    assertThat(lower.getTotalElements()).isEqualTo(1);
    assertThat(upper.getTotalElements()).isEqualTo(1);
    assertThat(mixed.getTotalElements()).isEqualTo(1);
  }

  @Test
  @Transactional
  void shouldReturnAlbumEntityWithHashAndArtists() {
    Album album = albumRepository.save(buildAlbum("The Wall"));

    Page<Album> result =
        albumRepository.findAllByNameContainingIgnoreCase("The Wall", PageRequest.of(0, 10));

    assertThat(result.getContent()).hasSize(1);
    Album found = result.getContent().getFirst();
    assertThat(found.getHash()).isEqualTo(album.getHash());
    assertThat(found.getArtists()).extracting(Artist::getHash).contains(artist.getHash());
    assertThat(found.getArtists()).extracting(Artist::getName).contains(artist.getName());
  }

  @Test
  void shouldNotMatchArtistNameWhenSearchingAlbumsByNameOnly() {
    albumRepository.save(buildAlbum("Artist Search Album"));

    Page<Album> result =
        albumRepository.findAllByNameContainingIgnoreCase("test artist", PageRequest.of(0, 10));

    assertThat(result.getContent()).isEmpty();
  }

  @Test
  void shouldReturnEmptyWhenNoAlbumNameMatches() {
    albumRepository.save(buildAlbum("Something Blue"));

    Page<Album> result =
        albumRepository.findAllByNameContainingIgnoreCase("zzznomatch", PageRequest.of(0, 10));

    assertThat(result).isEmpty();
  }

  @Test
  void shouldRespectPaginationWhenSearchingAlbumsByName() {
    for (int i = 0; i < 5; i++) {
      albumRepository.save(buildAlbum("Page Album " + i));
    }

    Page<Album> page0 =
        albumRepository.findAllByNameContainingIgnoreCase("Page Album", PageRequest.of(0, 2));
    Page<Album> page1 =
        albumRepository.findAllByNameContainingIgnoreCase("Page Album", PageRequest.of(1, 2));

    assertThat(page0.getContent()).hasSize(2);
    assertThat(page0.getTotalElements()).isEqualTo(5);
    assertThat(page1.getContent()).hasSize(2);
  }
}
