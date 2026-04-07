package com.example.musicplayerbackend.integration;

import com.example.musicplayerbackend.data.AlbumRepository;
import com.example.musicplayerbackend.data.ArtistRepository;
import com.example.musicplayerbackend.data.UserRepository;
import com.example.musicplayerbackend.domain.*;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.util.Base64;

import static org.hamcrest.Matchers.*;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

class AlbumControllerIntegrationTest extends BaseIntegrationTest {

    @Autowired
    AlbumRepository albumRepository;
    @Autowired
    ArtistRepository artistRepository;
    @Autowired
    UserRepository userRepository;

    User testUser;
    Album album;

    @BeforeEach
    void setUp() {
        testUser = userRepository.save(buildUser("album-test@example.com", Role.USER));

        Artist artist = artistRepository.save(Artist.builder().name("Test Artist").build());
        album = albumRepository.save(Album.builder()
                .name("Test Album")
                .artist(artist)
                .coverImage(Base64.getEncoder().encodeToString("img".getBytes()))
                .build());
    }

    @AfterEach
    void tearDown() {
        albumRepository.deleteAll();
        artistRepository.deleteAll();
        userRepository.deleteById(testUser.getId());
    }

    @Test
    void shouldReturn200WithPagedResults() throws Exception {
        mockMvc.perform(get("/api/v1/albums").with(user(testUser)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content", not(empty())))
                .andExpect(jsonPath("$.content[*].name", hasItem("Test Album")));
    }

    @Test
    void shouldFilterAlbumsByQuery() throws Exception {
        mockMvc.perform(get("/api/v1/albums").param("q", "Test").with(user(testUser)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content", not(empty())));
    }

    @Test
    void shouldReturnEmptyAlbumPageWhenQueryMatchesNothing() throws Exception {
        mockMvc.perform(get("/api/v1/albums").param("q", "nonexistentxyz").with(user(testUser)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content", empty()));
    }

    @Test
    void shouldReturn200ForAlbumByHash() throws Exception {
        mockMvc.perform(get("/api/v1/albums/{hash}", album.getHash()).with(user(testUser)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.hash").value(album.getHash()))
                .andExpect(jsonPath("$.name").value("Test Album"));
    }

    @Test
    void shouldReturn404WhenAlbumNotFound() throws Exception {
        mockMvc.perform(get("/api/v1/albums/nonexistent-hash").with(user(testUser)))
                .andExpect(status().isNotFound());
    }

    @Test
    void shouldReturn200WithAlbumCoverImageBytes() throws Exception {
        mockMvc.perform(get("/api/v1/albums/{hash}/cover", album.getHash()).with(user(testUser)))
                .andExpect(status().isOk())
                .andExpect(content().contentType("image/jpeg"));
    }

    @Test
    void shouldReturn404WhenAlbumHasNoCover() throws Exception {
        Album noCoverAlbum = albumRepository.save(Album.builder().name("No Cover Album").build());
        mockMvc.perform(get("/api/v1/albums/{hash}/cover", noCoverAlbum.getHash()).with(user(testUser)))
                .andExpect(status().isNotFound());
        albumRepository.delete(noCoverAlbum);
    }

    @Test
    void shouldSortAlbumsByNameDescWhenSortParamProvided() throws Exception {
        mockMvc.perform(get("/api/v1/albums").param("sort", "name,desc").with(user(testUser)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content").isArray());
    }

    @Test
    void shouldReturnArtistWhenPresentOnAlbum() throws Exception {
        mockMvc.perform(get("/api/v1/albums/{hash}", album.getHash()).with(user(testUser)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.artist.name").value("Test Artist"));
    }
}
