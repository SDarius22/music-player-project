package com.example.musicplayerbackend.integration;

import com.example.musicplayerbackend.data.PlaylistRepository;
import com.example.musicplayerbackend.data.SongRepository;
import com.example.musicplayerbackend.data.UserRepository;
import com.example.musicplayerbackend.domain.*;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;

import java.time.Instant;
import java.util.Base64;
import java.util.List;

import static org.hamcrest.Matchers.*;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

class PlaylistControllerIntegrationTest extends BaseIntegrationTest {

    @Autowired
    PlaylistRepository playlistRepository;
    @Autowired
    UserRepository userRepository;
    @Autowired
    SongRepository songRepository;
    @Autowired
    ObjectMapper objectMapper;

    User testUser;
    User otherUser;

    @BeforeEach
    void setUp() {
        testUser = userRepository.save(buildUser("playlist-test@example.com", Role.USER));
        otherUser = userRepository.save(buildUser("playlist-other@example.com", Role.USER));
    }

    @AfterEach
    void tearDown() {
        playlistRepository.deleteAll();
        songRepository.deleteAll();
        userRepository.deleteById(testUser.getId());
        userRepository.deleteById(otherUser.getId());
    }

    // ── GET /playlists ─────────────────────────────────────────────────────────

    @Test
    void shouldReturn200WithOwnedPlaylists() throws Exception {
        playlistRepository.save(Playlist.builder().user(testUser).name("My Mix")
                .createdAt(Instant.now()).updatedAt(Instant.now()).build());

        mockMvc.perform(get("/api/v1/playlists").with(user(testUser)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content", not(empty())))
                .andExpect(jsonPath("$.content[0].name").value("My Mix"));
    }

    @Test
    void shouldNotReturnOtherUserPlaylists() throws Exception {
        playlistRepository.save(Playlist.builder().user(otherUser).name("Other Mix")
                .createdAt(Instant.now()).updatedAt(Instant.now()).build());

        mockMvc.perform(get("/api/v1/playlists").with(user(testUser)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content", empty()));
    }

    // ── POST /playlists ───────────────────────────────────────────────────────

    @Test
    void shouldReturn201WhenCreatingPlaylist() throws Exception {
        Song song = songRepository.save(Song.builder()
                .name("Seed Song")
                .songType(ContentType.STREAMABLE)
                .fileHash("seed-hash-1")
                .build());

        PlaylistSongPositionDto item = new PlaylistSongPositionDto();
        item.setSongFileHash(song.getFileHash());
        item.setPosition(0);

        CreatePlaylistDto req = new CreatePlaylistDto();
        req.setName("New Playlist");
        req.setPlaylistSongs(List.of(item));

        mockMvc.perform(post("/api/v1/playlists")
                        .with(user(testUser))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.name").value("New Playlist"))
                .andExpect(jsonPath("$.id").isNumber());
    }

    // ── GET /playlists/{id} ───────────────────────────────────────────────────

    @Test
    void shouldReturn200ForPlaylistById() throws Exception {
        Playlist playlist = playlistRepository.save(Playlist.builder().user(testUser)
                .name("Detail Mix")
                .createdAt(Instant.now()).updatedAt(Instant.now()).build());

        mockMvc.perform(get("/api/v1/playlists/{id}", playlist.getId()).with(user(testUser)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(playlist.getId()))
                .andExpect(jsonPath("$.name").value("Detail Mix"));
    }

    @Test
    void shouldReturn404WhenPlaylistNotFound() throws Exception {
        mockMvc.perform(get("/api/v1/playlists/999999").with(user(testUser)))
                .andExpect(status().isNotFound());
    }

    @Test
    void shouldReturn403WhenPlaylistOwnedByOther() throws Exception {
        Playlist other = playlistRepository.save(Playlist.builder().user(otherUser)
                .name("Other")
                .createdAt(Instant.now()).updatedAt(Instant.now()).build());

        mockMvc.perform(get("/api/v1/playlists/{id}", other.getId()).with(user(testUser)))
                .andExpect(status().isForbidden());
    }

    // ── PUT /playlists/{id} ───────────────────────────────────────────────────

    @Test
    void shouldReturn200AndUpdatePlaylistName() throws Exception {
        Playlist playlist = playlistRepository.save(Playlist.builder().user(testUser)
                .name("Old Name")
                .createdAt(Instant.now()).updatedAt(Instant.now()).build());

        UpdatePlaylistDto req = new UpdatePlaylistDto();
        req.setName("New Name");
        req.setPlaylistSongs(null);

        mockMvc.perform(patch("/api/v1/playlists/{id}", playlist.getId())
                        .with(user(testUser))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.name").value("New Name"));
    }

    @Test
    void shouldReturn403WhenUpdatingPlaylistOwnedByOther() throws Exception {
        Playlist other = playlistRepository.save(Playlist.builder().user(otherUser)
                .name("Other")
                .createdAt(Instant.now()).updatedAt(Instant.now()).build());

        UpdatePlaylistDto req = new UpdatePlaylistDto();
        req.setName("Hijack");
        req.setPlaylistSongs(null);

        mockMvc.perform(patch("/api/v1/playlists/{id}", other.getId())
                        .with(user(testUser))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isForbidden());
    }

    // ── DELETE /playlists/{id} ────────────────────────────────────────────────

    @Test
    void shouldReturn204WhenDeletingPlaylist() throws Exception {
        Playlist playlist = playlistRepository.save(Playlist.builder().user(testUser)
                .name("Delete Me")
                .createdAt(Instant.now()).updatedAt(Instant.now()).build());

        mockMvc.perform(delete("/api/v1/playlists/{id}", playlist.getId()).with(user(testUser)))
                .andExpect(status().isNoContent());
    }

    @Test
    void shouldReturn403WhenDeletingPlaylistOwnedByOther() throws Exception {
        Playlist other = playlistRepository.save(Playlist.builder().user(otherUser)
                .name("Other")
                .createdAt(Instant.now()).updatedAt(Instant.now()).build());

        mockMvc.perform(delete("/api/v1/playlists/{id}", other.getId()).with(user(testUser)))
                .andExpect(status().isForbidden());
    }

    // ── GET /playlists/{id}/cover ─────────────────────────────────────────────

    @Test
    void shouldReturn200ForPlaylistCover() throws Exception {
        byte[] img = "imgbytes".getBytes();
        Playlist playlist = playlistRepository.save(Playlist.builder().user(testUser)
                .name("With Cover")
                .coverImage(Base64.getEncoder().encodeToString(img))
                .createdAt(Instant.now()).updatedAt(Instant.now()).build());

        mockMvc.perform(get("/api/v1/playlists/{id}/cover", playlist.getId()).with(user(testUser)))
                .andExpect(status().isOk());
    }

    @Test
    void shouldReturn403WhenPlaylistCoverOwnedByOther() throws Exception {
        byte[] img = "imgbytes".getBytes();
        Playlist other = playlistRepository.save(Playlist.builder().user(otherUser)
                .name("Other Cover")
                .coverImage(Base64.getEncoder().encodeToString(img))
                .createdAt(Instant.now()).updatedAt(Instant.now()).build());

        mockMvc.perform(get("/api/v1/playlists/{id}/cover", other.getId()).with(user(testUser)))
                .andExpect(status().isForbidden());
    }

    @Test
    void shouldReturn404WhenPlaylistHasNoCover() throws Exception {
        Playlist playlist = playlistRepository.save(Playlist.builder().user(testUser)
                .name("No Cover")
                .createdAt(Instant.now()).updatedAt(Instant.now()).build());

        mockMvc.perform(get("/api/v1/playlists/{id}/cover", playlist.getId()).with(user(testUser)))
                .andExpect(status().isNotFound());
    }
}
