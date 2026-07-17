package com.example.musicplayerbackend.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import com.example.musicplayerbackend.data.*;
import com.example.musicplayerbackend.domain.*;
import com.example.musicplayerbackend.mapper.NegotiationMapperImpl;
import com.example.musicplayerbackend.mapper.SongMapperImpl;
import java.lang.reflect.Field;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.api.io.TempDir;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.mock.web.MockMultipartFile;

@ExtendWith(MockitoExtension.class)
class SongServiceTest {

  @Mock SongRepository songRepository;
  @Mock ArtistRepository artistRepository;
  @Mock AlbumRepository albumRepository;
  @Mock ChunkRepository chunkRepository;
  @Mock SongChunkRepository songChunkRepository;
  @Mock UserLibraryRepository userLibraryRepository;
  @Mock SongEnrichmentService songEnrichmentService;
  @Mock DefaultPlaylistService defaultPlaylistService;

  @TempDir Path tempDir;

  SongMapperImpl songMapper;
  SongService service;

  @BeforeEach
  void setUp() throws Exception {
    songMapper = new SongMapperImpl();
    service =
        new SongService(
            songRepository,
            artistRepository,
            albumRepository,
            chunkRepository,
            songChunkRepository,
            userLibraryRepository,
            songMapper,
            songEnrichmentService,
            new NegotiationMapperImpl(),
            defaultPlaylistService);
    Field storageRoot = SongService.class.getDeclaredField("storageRoot");
    storageRoot.setAccessible(true);
    storageRoot.set(service, tempDir.toString());

    org.mockito.Mockito.lenient()
        .when(songEnrichmentService.enrich(anyList(), any()))
        .thenAnswer(
            inv -> {
              List<Song> songs = inv.getArgument(0);
              return songs.stream().map(songMapper::toDto).toList();
            });
    org.mockito.Mockito.lenient()
        .when(songEnrichmentService.enrich(any(Song.class), any()))
        .thenAnswer(
            inv -> {
              Song s = inv.getArgument(0);
              return songMapper.toDto(s);
            });
  }

  private User adminUser() {
    return User.builder()
        .id(1L)
        .email("admin@test.com")
        .role(Role.ADMIN)
        .provider(AuthProvider.LOCAL)
        .build();
  }

  private User regularUser() {
    return User.builder()
        .id(2L)
        .email("user@test.com")
        .role(Role.USER)
        .provider(AuthProvider.LOCAL)
        .allowed(true)
        .build();
  }

  private String sha256Hex(byte[] data) throws Exception {
    byte[] hash = MessageDigest.getInstance("SHA-256").digest(data);
    StringBuilder sb = new StringBuilder();
    for (byte b : hash) {
      String h = Integer.toHexString(0xff & b);
      if (h.length() == 1) sb.append('0');
      sb.append(h);
    }
    return sb.toString();
  }

  private String artistHash(String artistName) {
    try {
      return sha256Hex(artistName.getBytes());
    } catch (Exception e) {
      throw new RuntimeException(e);
    }
  }

  private String albumHash(String albumName) {
    try {
      return sha256Hex(albumName.getBytes());
    } catch (Exception e) {
      throw new RuntimeException(e);
    }
  }

  @Test
  void shouldReturnPageOfDtosVisibleToUser() {
    Song song =
        Song.builder().id(1L).name("Test").songType(ContentType.STREAMABLE).fileHash("h").build();
    User user = regularUser();
    when(songRepository.findAll(any(Specification.class), any(Pageable.class)))
        .thenReturn(new PageImpl<>(List.of(song)));

    Page<SongDto> result = service.getSongsVisibleToUser(null, user, Pageable.unpaged());

    assertEquals(1, result.getContent().size());
  }

  @Test
  void shouldPassQueryToRepositoryWhenSongsQueryProvided() {
    User user = regularUser();
    when(songRepository.findAll(any(Specification.class), any(Pageable.class)))
        .thenReturn(Page.empty());

    service.getSongsVisibleToUser("jazz", user, Pageable.unpaged());

    verify(songRepository).findAll(any(Specification.class), any(Pageable.class));
  }

  @Test
  void shouldReturnSongDto() {
    Song song =
        Song.builder().id(1L).name("S").songType(ContentType.STREAMABLE).fileHash("h").build();
    when(songRepository.findByFileHash("h")).thenReturn(Optional.of(song));

    assertEquals("h", service.getSongByFileHash("h", regularUser()).getFileHash());
  }

  @Test
  void shouldThrowRuntimeExceptionWhenSongByFileHashNotFound() {
    when(songRepository.findByFileHash("missing")).thenReturn(Optional.empty());
    assertThrows(RuntimeException.class, () -> service.getSongByFileHash("missing", regularUser()));
  }

  @Test
  void shouldThrowWhenNonAdminUploads() {
    User user = regularUser();
    assertThrows(
        RuntimeException.class,
        () ->
            service.uploadSong(
                user,
                "S",
                "A",
                "Album",
                null,
                120,
                1,
                1,
                2020,
                new MockMultipartFile("f", new byte[] {1}),
                "hash"));
  }

  @Test
  void shouldPromoteExistingSongOnDuplicate() throws Exception {
    User admin = adminUser();
    Song existing =
        Song.builder()
            .id(1L)
            .name("Dup")
            .songType(ContentType.USER_UPLOAD)
            .ownerId(5L)
            .fileHash("existing-hash")
            .build();
    when(songRepository.findByFileHash("existing-hash")).thenReturn(Optional.of(existing));
    when(songRepository.save(any())).thenReturn(existing);

    service.uploadSong(
        admin,
        "Dup",
        "Artist",
        "Album",
        null,
        120,
        1,
        1,
        2020,
        new MockMultipartFile("f", new byte[] {1}),
        "existing-hash");

    verify(songRepository)
        .save(argThat(s -> s.getSongType() == ContentType.STREAMABLE && s.getOwnerId() == null));
  }

  @Test
  void shouldCreateNewSongWhenNoExistingHashFound() throws Exception {
    User admin = adminUser();
    byte[] content = "audio content for testing chunks".getBytes();
    String hash = sha256Hex(content);
    MockMultipartFile file = new MockMultipartFile("file", content);

    when(songRepository.findByFileHash(hash)).thenReturn(Optional.empty());
    when(artistRepository.findByHash(artistHash("Artist"))).thenReturn(Optional.empty());
    when(artistRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
    when(albumRepository.findByHash(albumHash("Album"))).thenReturn(Optional.empty());
    when(albumRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
    Song savedSong =
        Song.builder()
            .id(10L)
            .name("New Song")
            .songType(ContentType.STREAMABLE)
            .fileHash(hash)
            .build();
    when(songRepository.save(any())).thenReturn(savedSong);
    when(chunkRepository.findByContentHash(any())).thenReturn(Optional.empty());
    when(chunkRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

    service.uploadSong(admin, "New Song", "Artist", "Album", null, 120, 1, 1, 2020, file, hash);

    verify(songRepository, atLeastOnce()).save(any());
  }

  @Test
  void shouldReuseExistingArtistAndAlbumWhenUploading() throws Exception {
    User admin = adminUser();
    byte[] content = "reuse artist and album".getBytes();
    String hash = sha256Hex(content);
    MockMultipartFile file = new MockMultipartFile("file", content);

    when(songRepository.findByFileHash(hash)).thenReturn(Optional.empty());
    Artist existingArtist =
        Artist.builder().id(1L).hash(artistHash("Artist")).name("Artist").build();
    when(artistRepository.findByHash(artistHash("Artist"))).thenReturn(Optional.of(existingArtist));
    Album existingAlbum =
        Album.builder()
            .id(1L)
            .hash(albumHash("Album"))
            .name("Album")
            .artists(Set.of(existingArtist))
            .build();
    when(albumRepository.findByHash(albumHash("Album"))).thenReturn(Optional.of(existingAlbum));
    Song savedSong =
        Song.builder().id(10L).name("New").songType(ContentType.STREAMABLE).fileHash(hash).build();
    when(songRepository.save(any())).thenReturn(savedSong);
    when(chunkRepository.findByContentHash(any())).thenReturn(Optional.empty());
    when(chunkRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

    service.uploadSong(admin, "New", "Artist", "Album", null, 120, 1, 1, 2020, file, hash);

    verify(artistRepository, never()).save(any());
    verify(albumRepository, never()).save(any());
  }

  @Test
  void shouldDeduplicateChunksWhenHashAlreadyExists() throws Exception {
    User admin = adminUser();
    byte[] content = "dedup chunk content bytes".getBytes();
    String fileHash = sha256Hex(content);
    MockMultipartFile file = new MockMultipartFile("file", content);

    when(songRepository.findByFileHash(fileHash)).thenReturn(Optional.empty());
    when(artistRepository.findByHash(any())).thenReturn(Optional.empty());
    when(artistRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
    when(albumRepository.findByHash(any())).thenReturn(Optional.empty());
    when(albumRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
    Song savedSong =
        Song.builder()
            .id(10L)
            .name("S")
            .songType(ContentType.STREAMABLE)
            .fileHash(fileHash)
            .build();
    when(songRepository.save(any())).thenReturn(savedSong);
    Chunk existingChunk =
        Chunk.builder().id(5L).contentHash("x").size(content.length).storagePath("/tmp/x").build();
    when(chunkRepository.findByContentHash(any())).thenReturn(Optional.of(existingChunk));

    service.uploadSong(admin, "S", "A", "B", null, 120, 1, 1, 2020, file, fileHash);

    verify(chunkRepository, never()).save(any(Chunk.class));
  }

  @Test
  void shouldCreateNewSongWhenNegotiationSongNotExists() throws Exception {
    NegotiationRequestDto req = new NegotiationRequestDto();
    req.setName("Upload Song");
    req.setArtistName("Artist");
    req.setAlbumName("Album");
    req.setFileHash("new-hash");
    req.setHashes(List.of("chunk-hash-0", "chunk-hash-1"));
    req.setDurationInSeconds(200);
    req.setTrackNumber(1);
    req.setDiscNumber(1);
    req.setReleaseYear(2024);

    when(songRepository.findByFileHash("new-hash")).thenReturn(Optional.empty());
    when(artistRepository.findByHash(artistHash("Artist"))).thenReturn(Optional.empty());
    when(artistRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
    when(albumRepository.findByHash(albumHash("Album"))).thenReturn(Optional.empty());
    when(albumRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
    Song newSong =
        Song.builder()
            .id(5L)
            .name("Upload Song")
            .songType(ContentType.USER_UPLOAD)
            .fileHash("new-hash")
            .build();
    when(songRepository.save(any())).thenReturn(newSong);
    when(songChunkRepository.existsBySongAndOrderIndex(any(), anyInt())).thenReturn(false);
    when(chunkRepository.findByContentHash(any())).thenReturn(Optional.empty());

    service.initiateNegotiation(req, 1L);

    verify(songRepository).save(any());
  }

  @Test
  void shouldDeduplicateExistingChunksDuringNegotiation() throws Exception {
    NegotiationRequestDto req = new NegotiationRequestDto();
    req.setName("Song");
    req.setArtistName("A");
    req.setAlbumName("B");
    req.setFileHash("fh");
    req.setHashes(List.of("existing-chunk-hash", "new-chunk-hash"));

    Song song =
        Song.builder().id(1L).name("Song").fileHash("fh").songType(ContentType.USER_UPLOAD).build();
    when(songRepository.findByFileHash("fh")).thenReturn(Optional.of(song));
    when(songChunkRepository.existsBySongAndOrderIndex(song, 0)).thenReturn(false);
    when(songChunkRepository.existsBySongAndOrderIndex(song, 1)).thenReturn(false);

    Chunk existingChunk =
        Chunk.builder()
            .id(1L)
            .contentHash("existing-chunk-hash")
            .size(100)
            .storagePath("/tmp/chunk")
            .build();
    when(chunkRepository.findByContentHash("existing-chunk-hash"))
        .thenReturn(Optional.of(existingChunk));
    when(chunkRepository.findByContentHash("new-chunk-hash")).thenReturn(Optional.empty());

    NegotiationResponseDto response = service.initiateNegotiation(req, 1L);

    assertEquals(List.of(1), response.getMissingIndices());
    verify(songChunkRepository).saveAll(argThat(list -> ((List<?>) list).size() == 1));
  }

  @Test
  void shouldReuseExistingArtistAndAlbumDuringNegotiation() throws Exception {
    NegotiationRequestDto req = new NegotiationRequestDto();
    req.setName("Song");
    req.setArtistName("ExistingArtist");
    req.setAlbumName("ExistingAlbum");
    req.setFileHash("fh-reuse");
    req.setHashes(List.of("chunk-hash"));

    when(songRepository.findByFileHash("fh-reuse")).thenReturn(Optional.empty());
    Artist existingArtist =
        Artist.builder().id(1L).hash(artistHash("ExistingArtist")).name("ExistingArtist").build();
    when(artistRepository.findByHash(artistHash("ExistingArtist")))
        .thenReturn(Optional.of(existingArtist));
    Album existingAlbum =
        Album.builder()
            .id(1L)
            .hash(albumHash("ExistingAlbum"))
            .name("ExistingAlbum")
            .artists(Set.of(existingArtist))
            .build();
    when(albumRepository.findByHash(albumHash("ExistingAlbum")))
        .thenReturn(Optional.of(existingAlbum));
    Song song =
        Song.builder()
            .id(3L)
            .name("Song")
            .fileHash("fh-reuse")
            .songType(ContentType.USER_UPLOAD)
            .build();
    when(songRepository.save(any())).thenReturn(song);
    when(songChunkRepository.existsBySongAndOrderIndex(song, 0)).thenReturn(false);
    when(chunkRepository.findByContentHash("chunk-hash")).thenReturn(Optional.empty());

    service.initiateNegotiation(req, 1L);

    verify(artistRepository, never()).save(any());
    verify(albumRepository, never()).save(any());
  }

  @Test
  void shouldReturnNothingMissingWhenHashListIsEmpty() throws Exception {
    NegotiationRequestDto req = new NegotiationRequestDto();
    req.setName("Song");
    req.setArtistName("A");
    req.setAlbumName("B");
    req.setFileHash("fh-empty");
    req.setHashes(List.of());

    Song song =
        Song.builder()
            .id(4L)
            .name("Song")
            .fileHash("fh-empty")
            .songType(ContentType.USER_UPLOAD)
            .build();
    when(songRepository.findByFileHash("fh-empty")).thenReturn(Optional.of(song));

    service.initiateNegotiation(req, 1L);

    verify(songChunkRepository, never()).saveAll(any());
  }

  @Test
  void shouldSkipExistingSongChunkLinksInNegotiation() throws Exception {
    NegotiationRequestDto req = new NegotiationRequestDto();
    req.setName("Song");
    req.setArtistName("A");
    req.setAlbumName("B");
    req.setFileHash("fh2");
    req.setHashes(List.of("hash0"));

    Song song =
        Song.builder()
            .id(2L)
            .name("Song")
            .fileHash("fh2")
            .songType(ContentType.USER_UPLOAD)
            .build();
    when(songRepository.findByFileHash("fh2")).thenReturn(Optional.of(song));
    when(songChunkRepository.existsBySongAndOrderIndex(song, 0)).thenReturn(true);

    service.initiateNegotiation(req, 1L);

    verify(songChunkRepository, never()).saveAll(any());
  }

  @Test
  void shouldThrowWhenSaveMissingChunkSongNotFound() {
    when(songRepository.findByFileHash("hash-99")).thenReturn(Optional.empty());
    assertThrows(
        RuntimeException.class,
        () ->
            service.saveMissingChunk(
                regularUser(), "hash-99", 0, "hash", new MockMultipartFile("f", new byte[] {1})));
  }

  @Test
  void shouldThrowWhenSaveMissingChunkCallerIsNotOwner() {
    Song song =
        Song.builder().id(1L).ownerId(5L).songType(ContentType.USER_UPLOAD).fileHash("h").build();
    when(songRepository.findByFileHash("h")).thenReturn(Optional.of(song));

    assertThrows(
        RuntimeException.class,
        () ->
            service.saveMissingChunk(
                regularUser(), "h", 0, "hash", new MockMultipartFile("f", new byte[] {1})));
  }

  @Test
  void shouldThrowWhenSaveMissingChunkTargetsStreamableSong() {
    Song song = Song.builder().id(1L).songType(ContentType.STREAMABLE).fileHash("h").build();
    when(songRepository.findByFileHash("h")).thenReturn(Optional.of(song));

    assertThrows(
        RuntimeException.class,
        () ->
            service.saveMissingChunk(
                regularUser(), "h", 0, "hash", new MockMultipartFile("f", new byte[] {1})));
  }

  @Test
  void shouldThrowOnChunkHashMismatch() {
    User owner =
        User.builder().id(1L).email("o@t.com").role(Role.USER).provider(AuthProvider.LOCAL).build();
    Song song =
        Song.builder().id(1L).ownerId(1L).songType(ContentType.USER_UPLOAD).fileHash("h").build();
    when(songRepository.findByFileHash("h")).thenReturn(Optional.of(song));

    assertThrows(
        RuntimeException.class,
        () ->
            service.saveMissingChunk(
                owner, "h", 0, "wrong-hash", new MockMultipartFile("f", "chunk".getBytes())));
  }

  @Test
  void shouldSaveChunkAndLinkWhenValid() throws Exception {
    User owner =
        User.builder().id(1L).email("o@t.com").role(Role.USER).provider(AuthProvider.LOCAL).build();
    Song song =
        Song.builder().id(1L).ownerId(1L).songType(ContentType.USER_UPLOAD).fileHash("h").build();
    byte[] data = "valid chunk data".getBytes();
    String correctHash = sha256Hex(data);

    when(songRepository.findByFileHash("h")).thenReturn(Optional.of(song));
    when(chunkRepository.findByContentHash(correctHash)).thenReturn(Optional.empty());
    when(chunkRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
    when(songChunkRepository.existsBySongAndOrderIndex(song, 0)).thenReturn(false);

    service.saveMissingChunk(owner, "h", 0, correctHash, new MockMultipartFile("f", data));

    verify(chunkRepository).save(any());
    verify(songChunkRepository).save(any());
  }

  @Test
  void shouldRecoverFromConcurrentChunkSave() throws Exception {
    User owner =
        User.builder().id(1L).email("o@t.com").role(Role.USER).provider(AuthProvider.LOCAL).build();
    Song song =
        Song.builder().id(1L).ownerId(1L).songType(ContentType.USER_UPLOAD).fileHash("h").build();
    byte[] data = "concurrent chunk data".getBytes();
    String correctHash = sha256Hex(data);

    when(songRepository.findByFileHash("h")).thenReturn(Optional.of(song));
    when(chunkRepository.findByContentHash(correctHash)).thenReturn(Optional.empty());
    Chunk savedByRace =
        Chunk.builder()
            .id(99L)
            .contentHash(correctHash)
            .size(data.length)
            .storagePath("/tmp/x")
            .build();
    when(chunkRepository.save(any())).thenThrow(new DataIntegrityViolationException("duplicate"));
    when(chunkRepository.findByContentHash(correctHash))
        .thenReturn(Optional.empty())
        .thenReturn(Optional.of(savedByRace));
    when(songChunkRepository.existsBySongAndOrderIndex(song, 0)).thenReturn(false);

    service.saveMissingChunk(owner, "h", 0, correctHash, new MockMultipartFile("f", data));

    verify(songChunkRepository).save(any());
  }

  @Test
  void shouldSkipLinkCreationWhenChunkLinkAlreadyExists() throws Exception {
    User owner =
        User.builder().id(1L).email("o@t.com").role(Role.USER).provider(AuthProvider.LOCAL).build();
    Song song =
        Song.builder().id(1L).ownerId(1L).songType(ContentType.USER_UPLOAD).fileHash("h").build();
    byte[] data = "link exists data ok".getBytes();
    String correctHash = sha256Hex(data);

    Chunk existingChunk =
        Chunk.builder()
            .id(10L)
            .contentHash(correctHash)
            .size(data.length)
            .storagePath("/tmp/existing")
            .build();
    when(songRepository.findByFileHash("h")).thenReturn(Optional.of(song));
    when(chunkRepository.findByContentHash(correctHash)).thenReturn(Optional.of(existingChunk));
    when(songChunkRepository.existsBySongAndOrderIndex(song, 0)).thenReturn(true);

    service.saveMissingChunk(owner, "h", 0, correctHash, new MockMultipartFile("f", data));

    verify(songChunkRepository, never()).save(any());
  }

  @Test
  void shouldReuseExistingChunkWhenSavingMissingChunk() throws Exception {
    User owner =
        User.builder().id(1L).email("o@t.com").role(Role.USER).provider(AuthProvider.LOCAL).build();
    Song song =
        Song.builder().id(1L).ownerId(1L).songType(ContentType.USER_UPLOAD).fileHash("h").build();
    byte[] data = "existing chunk".getBytes();
    String correctHash = sha256Hex(data);

    Chunk existingChunk =
        Chunk.builder()
            .id(10L)
            .contentHash(correctHash)
            .size(data.length)
            .storagePath("/tmp/existing")
            .build();
    when(songRepository.findByFileHash("h")).thenReturn(Optional.of(song));
    when(chunkRepository.findByContentHash(correctHash)).thenReturn(Optional.of(existingChunk));
    when(songChunkRepository.existsBySongAndOrderIndex(song, 0)).thenReturn(false);

    service.saveMissingChunk(owner, "h", 0, correctHash, new MockMultipartFile("f", data));

    verify(chunkRepository, never()).save(any());
    verify(songChunkRepository).save(any());
  }
}
