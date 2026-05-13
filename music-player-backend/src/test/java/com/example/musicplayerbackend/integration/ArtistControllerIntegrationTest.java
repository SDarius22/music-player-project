package com.example.musicplayerbackend.integration;

import com.example.musicplayerbackend.data.AlbumRepository;
import com.example.musicplayerbackend.data.ArtistRepository;
import com.example.musicplayerbackend.data.SongRepository;
import com.example.musicplayerbackend.data.UserRepository;
import com.example.musicplayerbackend.domain.*;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.util.Base64;
import java.util.Set;

import static org.hamcrest.Matchers.*;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

class ArtistControllerIntegrationTest extends BaseIntegrationTest {

    @Autowired
    ArtistRepository artistRepository;
    @Autowired
    AlbumRepository albumRepository;
    @Autowired
    SongRepository songRepository;
    @Autowired
    UserRepository userRepository;

    User testUser;
    Artist artist;
    Album album;

    @BeforeEach
    void setUp() {
        testUser = userRepository.save(buildUser("artist-test@example.com", Role.USER));
        artist = artistRepository.save(Artist.builder()
                .name("Test Artist")
                .build());
        album = albumRepository.save(Album.builder()
                .name("Test Album")
                .artists(Set.of(artist))
                .coverImage(Base64.getEncoder().encodeToString("img".getBytes()))
                .build());
        songRepository.save(Song.builder()
                .name("Test Song")
                .artist(artist)
                .album(album)
                .songType(ContentType.STREAMABLE)
                .fileHash("artist-test-hash-001")
                .build());
        songRepository.save(Song.builder()
                .name("Another Song")
                .artist(artist)
                .album(album)
                .songType(ContentType.STREAMABLE)
                .fileHash("artist-test-hash-000")
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
    void shouldReturn200WithArtistResults() throws Exception {
        mockMvc.perform(get("/api/v1/artists").with(user(testUser)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content", not(empty())))
                .andExpect(jsonPath("$.content[0].hash").isNotEmpty())
                .andExpect(jsonPath("$.content[0].hash").value(artist.getHash()))
                .andExpect(jsonPath("$.content[0].name").value("Test Artist"))
                .andExpect(jsonPath("$.content[0].songFileHashes", containsInAnyOrder(
                        "artist-test-hash-001",
                        "artist-test-hash-000"
                )));
    }

    @Test
    void shouldFilterArtistsByQuery() throws Exception {
        mockMvc.perform(get("/api/v1/artists").param("q", "Test").with(user(testUser)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content", not(empty())));
    }

    @Test
    void shouldReturnEmptyArtistsWhenQueryMatchesNothing() throws Exception {
        mockMvc.perform(get("/api/v1/artists").param("q", "zzznomatch").with(user(testUser)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content", empty()));
    }

    @Test
    void shouldReturn200ForArtistByHash() throws Exception {
        mockMvc.perform(get("/api/v1/artists/{artistHash}", artist.getHash()).with(user(testUser)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.hash").value(artist.getHash()))
                .andExpect(jsonPath("$.name").value("Test Artist"));
    }

    @Test
    void shouldReturn404WhenArtistNotFound() throws Exception {
        mockMvc.perform(get("/api/v1/artists/999999").with(user(testUser)))
                .andExpect(status().isNotFound());
    }

    @Test
    void shouldReturn200ForArtistCover() throws Exception {
        mockMvc.perform(get("/api/v1/artists/{artistHash}/cover", artist.getHash()).with(user(testUser)))
                .andExpect(status().isOk())
                .andExpect(content().contentType("image/jpeg"));
    }

    @Test
    void shouldReturn404WhenArtistCoverNotFound() throws Exception {
        mockMvc.perform(get("/api/v1/artists/999999/cover").with(user(testUser)))
                .andExpect(status().isNotFound());
    }

    @Test
    void shouldReturnSongsForArtist() throws Exception {
        mockMvc.perform(get("/api/v1/artists/{artistHash}", artist.getHash()).with(user(testUser)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.songFileHashes", not(empty())));
    }

    @Test
    void shouldReturnArtistSongsOrderedByName() throws Exception {
        mockMvc.perform(get("/api/v1/artists/{artistHash}/songs", artist.getHash()).with(user(testUser)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content[0].name").value("Another Song"))
                .andExpect(jsonPath("$.content[1].name").value("Test Song"));
    }
}
