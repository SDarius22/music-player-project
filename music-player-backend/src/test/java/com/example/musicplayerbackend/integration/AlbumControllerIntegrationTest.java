package com.example.musicplayerbackend.integration;

import static org.hamcrest.Matchers.*;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

import com.example.musicplayerbackend.data.AlbumRepository;
import com.example.musicplayerbackend.data.ArtistRepository;
import com.example.musicplayerbackend.data.SongRepository;
import com.example.musicplayerbackend.data.UserRepository;
import com.example.musicplayerbackend.domain.Album;
import com.example.musicplayerbackend.domain.Artist;
import com.example.musicplayerbackend.domain.ContentType;
import com.example.musicplayerbackend.domain.Role;
import com.example.musicplayerbackend.domain.Song;
import com.example.musicplayerbackend.domain.User;
import java.util.Base64;
import java.util.Set;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

class AlbumControllerIntegrationTest extends BaseIntegrationTest {

  @Autowired AlbumRepository albumRepository;
  @Autowired ArtistRepository artistRepository;
  @Autowired SongRepository songRepository;
  @Autowired UserRepository userRepository;

  User testUser;
  Album album;

  @BeforeEach
  void setUp() {
    testUser = userRepository.save(buildUser("album-test@example.com", Role.USER));

    Artist artist = artistRepository.save(Artist.builder().name("Test Artist").build());
    album =
        albumRepository.save(
            Album.builder()
                .name("Test Album")
                .artists(Set.of(artist))
                .coverImage(Base64.getEncoder().encodeToString("img".getBytes()))
                .build());

    songRepository.save(
        Song.builder()
            .name("Disc 2 Track 1")
            .artist(artist)
            .album(album)
            .discNumber(2)
            .trackNumber(1)
            .songType(ContentType.STREAMABLE)
            .fileHash("album-song-002001")
            .build());
    songRepository.save(
        Song.builder()
            .name("Disc 1 Track 2")
            .artist(artist)
            .album(album)
            .discNumber(1)
            .trackNumber(2)
            .songType(ContentType.STREAMABLE)
            .fileHash("album-song-001002")
            .build());
  }

  @AfterEach
  void tearDown() {
    songRepository.deleteAll();
    albumRepository.deleteAll();
    artistRepository.deleteAll();
    userRepository.deleteById(testUser.getId());
  }

  @Test
  void shouldReturn200WithPagedResults() throws Exception {
    mockMvc
        .perform(get("/api/v1/albums").with(user(testUser)))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.content", not(empty())))
        .andExpect(jsonPath("$.content[*].name", hasItem("Test Album")))
        .andExpect(jsonPath("$.content[0].hash", not(isEmptyOrNullString())))
        .andExpect(jsonPath("$.content[0].artist.name", not(isEmptyOrNullString())))
        .andExpect(jsonPath("$.content[0].songFileHashes").isArray());
  }

  @Test
  void shouldFilterAlbumsByQuery() throws Exception {
    mockMvc
        .perform(get("/api/v1/albums").param("q", "Test").with(user(testUser)))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.content", not(empty())));
  }

  @Test
  void shouldReturnEmptyAlbumPageWhenQueryMatchesNothing() throws Exception {
    mockMvc
        .perform(get("/api/v1/albums").param("q", "nonexistentxyz").with(user(testUser)))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.content", empty()));
  }

  @Test
  void shouldReturn200ForAlbumByHash() throws Exception {
    mockMvc
        .perform(get("/api/v1/albums/{hash}", album.getHash()).with(user(testUser)))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.hash").value(album.getHash()))
        .andExpect(jsonPath("$.name").value("Test Album"));
  }

  @Test
  void shouldReturn404WhenAlbumNotFound() throws Exception {
    mockMvc
        .perform(get("/api/v1/albums/nonexistent-hash").with(user(testUser)))
        .andExpect(status().isNotFound());
  }

  @Test
  void shouldReturn200WithAlbumCoverImageBytes() throws Exception {
    mockMvc
        .perform(get("/api/v1/albums/{hash}/cover", album.getHash()).with(user(testUser)))
        .andExpect(status().isOk())
        .andExpect(content().contentType("image/jpeg"));
  }

  @Test
  void shouldReturn404WhenAlbumHasNoCover() throws Exception {
    Album noCoverAlbum = albumRepository.save(Album.builder().name("No Cover Album").build());
    mockMvc
        .perform(get("/api/v1/albums/{hash}/cover", noCoverAlbum.getHash()).with(user(testUser)))
        .andExpect(status().isNotFound());
    albumRepository.delete(noCoverAlbum);
  }

  @Test
  void shouldSortAlbumsByNameDescWhenSortParamProvided() throws Exception {
    mockMvc
        .perform(get("/api/v1/albums").param("sort", "name,desc").with(user(testUser)))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.content").isArray());
  }

  @Test
  void shouldReturnArtistWhenPresentOnAlbum() throws Exception {
    mockMvc
        .perform(get("/api/v1/albums/{hash}", album.getHash()).with(user(testUser)))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.artist.name").value("Test Artist"));
  }

  @Test
  void shouldReturnAlbumSongsOrderedByDiscThenTrack() throws Exception {
    mockMvc
        .perform(get("/api/v1/albums/{hash}/songs", album.getHash()).with(user(testUser)))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.content[0].fileHash").value("album-song-001002"))
        .andExpect(jsonPath("$.content[1].fileHash").value("album-song-002001"));
  }
}
