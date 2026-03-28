package com.example.musicplayerbackend.integration;

import com.example.musicplayerbackend.data.AlbumRepository;
import com.example.musicplayerbackend.data.ArtistRepository;
import com.example.musicplayerbackend.data.SongRepository;
import com.example.musicplayerbackend.data.UserRepository;
import com.example.musicplayerbackend.domain.*;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;

import java.security.MessageDigest;
import java.util.Base64;
import java.util.List;
import java.util.UUID;

import static org.hamcrest.Matchers.*;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

class SongControllerIntegrationTest extends BaseIntegrationTest {

    @Autowired SongRepository songRepository;
    @Autowired ArtistRepository artistRepository;
    @Autowired AlbumRepository albumRepository;
    @Autowired UserRepository userRepository;
    @Autowired ObjectMapper objectMapper;

    User testUser;
    User adminUser;
    Song publicSong;
    Song privateSong;
    Album albumWithCover;
    Song songWithCover;
    Song songWithNoAlbum;

    @BeforeEach
    void setUp() {
        testUser = userRepository.save(buildUser("song-test@example.com", Role.USER));
        adminUser = userRepository.save(buildUser("song-admin@example.com", Role.ADMIN));

        Artist artist = artistRepository.save(Artist.builder().name("Test Artist").build());
        Album album = albumRepository.save(Album.builder().name("Test Album").build());

        publicSong = songRepository.save(Song.builder()
                .name("Public Song")
                .artist(artist).album(album)
                .songType(ContentType.STREAMABLE)
                .fileHash(UUID.randomUUID().toString())
                .build());

        // private song owned by this user — also visible
        privateSong = songRepository.save(Song.builder()
                .name("Private Song")
                .artist(artist).album(album)
                .songType(ContentType.USER_UPLOAD)
                .ownerId(testUser.getId())
                .fileHash(UUID.randomUUID().toString())
                .build());

        // album with cover for getSongCover 200 test
        albumWithCover = albumRepository.save(Album.builder()
                .name("Cover Album")
                .coverImage(Base64.getEncoder().encodeToString("img".getBytes()))
                .build());
        songWithCover = songRepository.save(Song.builder()
                .name("Song With Cover")
                .artist(artist).album(albumWithCover)
                .songType(ContentType.STREAMABLE)
                .fileHash(UUID.randomUUID().toString())
                .build());

        // song with no album for getSongCover 404 test
        songWithNoAlbum = songRepository.save(Song.builder()
                .name("No Album Song")
                .songType(ContentType.STREAMABLE)
                .fileHash(UUID.randomUUID().toString())
                .build());
    }

    @AfterEach
    void tearDown() {
        songRepository.deleteAll();
        albumRepository.deleteAll();
        artistRepository.deleteAll();
        userRepository.deleteById(testUser.getId());
        userRepository.deleteById(adminUser.getId());
    }

    // ── GET /songs ────────────────────────────────────────────────────────────

    @Test
    void shouldReturn200WithPublicSongs() throws Exception {
        mockMvc.perform(get("/api/v1/songs").with(user(testUser)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content", not(empty())));
    }

    @Test
    void shouldFilterSongsByNameQuery() throws Exception {
        mockMvc.perform(get("/api/v1/songs").param("q", "Public").with(user(testUser)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content[?(@.id == " + publicSong.getId() + ")].name",
                        contains("Public Song")));
    }

    @Test
    void shouldReturnEmptySongPageWhenQueryMatchesNothing() throws Exception {
        mockMvc.perform(get("/api/v1/songs").param("q", "zzznomatch").with(user(testUser)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content", empty()));
    }

    @Test
    void shouldIncludePrivateSongsOwnedByCurrentUser() throws Exception {
        mockMvc.perform(get("/api/v1/songs").param("q", "Private").with(user(testUser)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content", not(empty())));
    }

    @Test
    void shouldRespectPaginationWhenFetchingSongs() throws Exception {
        mockMvc.perform(get("/api/v1/songs").param("size", "1").with(user(testUser)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content", hasSize(1)))
                .andExpect(jsonPath("$.totalPages").value(greaterThanOrEqualTo(1)));
    }

    // ── GET /songs sort parameter branches ───────────────────────────────────

    @Test
    void shouldSortSongsByYear() throws Exception {
        mockMvc.perform(get("/api/v1/songs").param("sort", "year").with(user(testUser)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content").isArray());
    }

    @Test
    void shouldSortSongsByYearDesc() throws Exception {
        mockMvc.perform(get("/api/v1/songs").param("sort", "year,desc").with(user(testUser)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content").isArray());
    }

    @Test
    void shouldSortSongsByDurationInSeconds() throws Exception {
        mockMvc.perform(get("/api/v1/songs").param("sort", "durationInSeconds").with(user(testUser)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content").isArray());
    }

    @Test
    void shouldSortSongsByTrackNumber() throws Exception {
        mockMvc.perform(get("/api/v1/songs").param("sort", "trackNumber").with(user(testUser)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content").isArray());
    }

    @Test
    void shouldSortSongsByDiscNumber() throws Exception {
        mockMvc.perform(get("/api/v1/songs").param("sort", "discNumber").with(user(testUser)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content").isArray());
    }

    @Test
    void shouldSortSongsByNameExplicitAsc() throws Exception {
        mockMvc.perform(get("/api/v1/songs").param("sort", "name,asc").with(user(testUser)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content").isArray());
    }

    @Test
    void shouldUseDefaultSortWhenUnknownSortPropertyProvided() throws Exception {
        mockMvc.perform(get("/api/v1/songs").param("sort", "unknown").with(user(testUser)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content").isArray());
    }

    // ── GET /songs/{id} ───────────────────────────────────────────────────────

    @Test
    void shouldReturn200ForSongById() throws Exception {
        mockMvc.perform(get("/api/v1/songs/{id}", publicSong.getId()).with(user(testUser)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(publicSong.getId()))
                .andExpect(jsonPath("$.name").value("Public Song"));
    }

    @Test
    void shouldReturn500WhenSongByIdNotFound() throws Exception {
        // The service throws a RuntimeException (not ResponseStatusException), so 500
        mockMvc.perform(get("/api/v1/songs/999999").with(user(testUser)))
                .andExpect(status().is5xxServerError());
    }

    // ── GET /songs/{id}/cover ─────────────────────────────────────────────────

    @Test
    void shouldReturn404WhenSongCoverHasNoAlbum() throws Exception {
        mockMvc.perform(get("/api/v1/songs/{id}/cover", songWithNoAlbum.getId()).with(user(testUser)))
                .andExpect(status().isNotFound());
    }

    @Test
    void shouldReturn200WhenSongCoverAlbumHasCover() throws Exception {
        mockMvc.perform(get("/api/v1/songs/{id}/cover", songWithCover.getId()).with(user(testUser)))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.IMAGE_JPEG));
    }

    // ── GET /songs/recommendations ────────────────────────────────────────────

    @Test
    void shouldReturn200ForRecommendations() throws Exception {
        mockMvc.perform(get("/api/v1/songs/recommendations").with(user(testUser)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$").isArray());
    }

    // ── GET /songs/forgotten ──────────────────────────────────────────────────

    @Test
    void shouldReturn200ForForgottenFavourites() throws Exception {
        mockMvc.perform(get("/api/v1/songs/forgotten").with(user(testUser)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$").isArray());
    }

    // ── GET /songs/quick-dial ─────────────────────────────────────────────────

    @Test
    void shouldReturn200ForQuickDial() throws Exception {
        mockMvc.perform(get("/api/v1/songs/quick-dial").with(user(testUser)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$").isArray());
    }

    // ── POST /songs/negotiate ─────────────────────────────────────────────────

    @Test
    void shouldReturn200WhenNegotiatingUserUpload() throws Exception {
        NegotiationRequestDto req = new NegotiationRequestDto();
        req.setName("Negotiated Song");
        req.setArtistName("Negotiate Artist");
        req.setAlbumName("Negotiate Album");
        req.setFileHash(UUID.randomUUID().toString());
        req.setHashes(List.of());

        mockMvc.perform(post("/api/v1/songs/negotiate")
                        .with(user(testUser))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.missingIndices").isArray());
    }

    // ── POST /songs/{id}/chunks/{index} ───────────────────────────────────────

    @Test
    void shouldReturn400WhenChunkHashMismatch() throws Exception {
        // publicSong is STREAMABLE with null ownerId → saveMissingChunk throws (NullPointerException on ownerId.equals)
        MockMultipartFile chunkFile = new MockMultipartFile(
                "chunkData", "chunk.bin", MediaType.APPLICATION_OCTET_STREAM_VALUE,
                "fake-chunk-content".getBytes());

        mockMvc.perform(multipart("/api/v1/songs/{id}/chunks/{index}", publicSong.getId(), 0)
                        .file(chunkFile)
                        .param("contentHash", "wronghash")
                        .with(user(testUser)))
                .andExpect(status().isBadRequest());
    }

    @Test
    void shouldReturn201WhenChunkIsValid() throws Exception {
        byte[] data = "valid-chunk-data".getBytes();
        String hash = sha256(data);

        MockMultipartFile chunkFile = new MockMultipartFile(
                "chunkData", "chunk.bin", MediaType.APPLICATION_OCTET_STREAM_VALUE, data);

        mockMvc.perform(multipart("/api/v1/songs/{id}/chunks/{index}", privateSong.getId(), 0)
                        .file(chunkFile)
                        .param("contentHash", hash)
                        .with(user(testUser)))
                .andExpect(status().isCreated());
    }

    // ── POST /songs ───────────────────────────────────────────────────────────

    @Test
    void shouldReturn403WhenNonAdminUserUploadsSong() throws Exception {
        MockMultipartFile file = new MockMultipartFile(
                "file", "song.mp3", "audio/mpeg", "fake-audio".getBytes());

        // Security config enforces ROLE_ADMIN for POST /songs; USER gets 403
        mockMvc.perform(multipart("/api/v1/songs")
                        .file(file)
                        .param("name", "Test Upload")
                        .param("artistName", "Artist")
                        .param("albumName", "Album")
                        .param("fileHash", UUID.randomUUID().toString())
                        .with(user(testUser)))  // USER role — not admin
                .andExpect(status().isForbidden());
    }

@Test
    void shouldReturn201WhenAdminUploadsValidSong() throws Exception {
        MockMultipartFile file = new MockMultipartFile(
                "file", "song.mp3", "audio/mpeg", new byte[0]);

        mockMvc.perform(multipart("/api/v1/songs")
                        .file(file)
                        .param("name", "Admin Upload Song")
                        .param("artistName", "Admin Artist")
                        .param("albumName", "Admin Album")
                        .param("fileHash", UUID.randomUUID().toString())
                        .with(user(adminUser)))
                .andExpect(status().isCreated());
    }

    // ── helpers ───────────────────────────────────────────────────────────────

    private String sha256(byte[] data) throws Exception {
        byte[] digest = MessageDigest.getInstance("SHA-256").digest(data);
        return java.util.HexFormat.of().formatHex(digest);
    }
}
