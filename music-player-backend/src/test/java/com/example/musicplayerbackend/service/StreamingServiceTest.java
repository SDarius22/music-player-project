package com.example.musicplayerbackend.service;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.when;

import com.example.musicplayerbackend.data.SongChunkRepository;
import com.example.musicplayerbackend.data.SongRepository;
import com.example.musicplayerbackend.domain.*;
import java.io.File;
import java.io.FileOutputStream;
import java.nio.file.Path;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.api.io.TempDir;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

@ExtendWith(MockitoExtension.class)
class StreamingServiceTest {

  @Mock SongRepository songRepository;

  @Mock SongChunkRepository songChunkRepository;

  @TempDir Path tempDir;

  StreamingService service;

  @BeforeEach
  void setUp() {
    service = new StreamingService(songRepository, songChunkRepository);
  }

  private Song streamableSong(long id) {
    Song song =
        Song.builder()
            .id(id)
            .name("Song " + id)
            .songType(ContentType.STREAMABLE)
            .fileHash("hash-" + id)
            .build();
    song.setChunks(new java.util.ArrayList<>());
    return song;
  }

  private Chunk chunkWithFile(byte[] data) throws Exception {
    File f = tempDir.resolve("chunk-" + System.nanoTime()).toFile();
    try (FileOutputStream fos = new FileOutputStream(f)) {
      fos.write(data);
    }
    return Chunk.builder()
        .id(1L)
        .contentHash("h")
        .size(data.length)
        .storagePath(f.getAbsolutePath())
        .build();
  }

  private SongChunk songChunk(Song song, Chunk chunk, int idx) {
    return SongChunk.builder().song(song).chunk(chunk).orderIndex(idx).build();
  }

  @Test
  void shouldReturnManifestForPublicSong() throws Exception {
    Song song = streamableSong(1L);
    Chunk chunk = chunkWithFile("data".getBytes());
    song.getChunks().add(songChunk(song, chunk, 0));
    when(songRepository.findByFileHash("hash-1")).thenReturn(Optional.of(song));

    ChunkManifestDto manifest = service.getSongManifest("hash-1", 99L);

    assertEquals("hash-1", manifest.getFileHash());
    assertEquals(1, manifest.getTotalChunks());
    assertEquals(65536, manifest.getChunkSize());
    assertEquals(List.of("h"), manifest.getHashes());
  }

  @Test
  void shouldRejectPublicSongForUserNotOnAllowList() {
    Song song = streamableSong(1L);
    when(songRepository.findByFileHash("hash-1")).thenReturn(Optional.of(song));
    User user = User.builder().id(99L).role(Role.USER).allowed(false).build();

    ResponseStatusException ex =
        assertThrows(
            ResponseStatusException.class,
            () -> service.getSongManifest("hash-1", user));

    assertEquals(HttpStatus.NOT_FOUND, ex.getStatusCode());
  }

  @Test
  void shouldThrow404WhenManifestPrivateSongOwnedByOther() {
    Song song = streamableSong(1L);
    song.setOwnerId(5L);
    when(songRepository.findByFileHash("hash-1")).thenReturn(Optional.of(song));

    ResponseStatusException ex =
        assertThrows(ResponseStatusException.class, () -> service.getSongManifest("hash-1", 99L));
    assertEquals(HttpStatus.NOT_FOUND, ex.getStatusCode());
  }

  @Test
  void shouldSucceedWhenManifestPrivateSongOwnedBySameUser() throws Exception {
    Song song = streamableSong(1L);
    song.setOwnerId(5L);
    Chunk chunk = chunkWithFile("data".getBytes());
    song.getChunks().add(songChunk(song, chunk, 0));
    when(songRepository.findByFileHash("hash-1")).thenReturn(Optional.of(song));

    ChunkManifestDto manifest = service.getSongManifest("hash-1", 5L);

    assertNotNull(manifest);
  }

  @Test
  void shouldReturnEmptyManifestWhenNoChunks() {
    Song song = streamableSong(2L);
    when(songRepository.findByFileHash("hash-2")).thenReturn(Optional.of(song));

    ChunkManifestDto manifest = service.getSongManifest("hash-2", 99L);

    assertEquals(0, manifest.getTotalChunks());
    assertEquals(0L, manifest.getTotalBytes());
    assertTrue(manifest.getHashes().isEmpty());
  }

  @Test
  void shouldAccumulateTotalBytesForMultipleChunks() throws Exception {
    Song song = streamableSong(3L);
    Chunk c1 = chunkWithFile("chunk1data".getBytes());
    Chunk c2 =
        Chunk.builder()
            .id(2L)
            .contentHash("h2")
            .size(500)
            .storagePath(tempDir.resolve("c2").toAbsolutePath().toString())
            .build();
    try (FileOutputStream fos = new FileOutputStream(c2.getStoragePath())) {
      fos.write(new byte[500]);
    }
    song.getChunks().add(songChunk(song, c1, 0));
    song.getChunks().add(songChunk(song, c2, 1));
    when(songRepository.findByFileHash("hash-3")).thenReturn(Optional.of(song));

    ChunkManifestDto manifest = service.getSongManifest("hash-3", 99L);

    assertEquals(2, manifest.getTotalChunks());
    assertEquals((long) c1.getSize() + 500L, manifest.getTotalBytes());
  }

  @Test
  void shouldThrow404WhenManifestSongNotFound() {
    when(songRepository.findByFileHash("hash-1")).thenReturn(Optional.empty());
    assertThrows(ResponseStatusException.class, () -> service.getSongManifest("hash-1", 1L));
  }

  @Test
  void shouldReturnChunkResource() throws Exception {
    byte[] data = "audio-data".getBytes();
    Song song = streamableSong(1L);
    Chunk chunk = chunkWithFile(data);
    SongChunk sc = songChunk(song, chunk, 0);
    song.getChunks().add(sc);
    when(songRepository.findByFileHash("hash-1")).thenReturn(Optional.of(song));
    when(songChunkRepository.findWithChunkBySongAndOrderIndex(song, 0))
        .thenReturn(Optional.of(sc));

    Resource resource = service.getSongChunk("hash-1", 0, 99L);

    assertNotNull(resource);
    assertTrue(resource.exists());
  }

  @Test
  void shouldThrowBadRequestWhenChunkIndexIsOutOfBounds() throws Exception {
    Song song = streamableSong(1L);
    Chunk chunk = chunkWithFile("x".getBytes());
    song.getChunks().add(songChunk(song, chunk, 0));
    when(songRepository.findByFileHash("hash-1")).thenReturn(Optional.of(song));

    ResponseStatusException ex =
        assertThrows(ResponseStatusException.class, () -> service.getSongChunk("hash-1", 5, 99L));
    assertEquals(HttpStatus.BAD_REQUEST, ex.getStatusCode());
  }

  @Test
  void shouldThrowBadRequestWhenChunkIndexIsNegative() throws Exception {
    Song song = streamableSong(1L);
    Chunk chunk = chunkWithFile("x".getBytes());
    song.getChunks().add(songChunk(song, chunk, 0));
    when(songRepository.findByFileHash("hash-1")).thenReturn(Optional.of(song));

    ResponseStatusException ex =
        assertThrows(ResponseStatusException.class, () -> service.getSongChunk("hash-1", -1, 99L));
    assertEquals(HttpStatus.BAD_REQUEST, ex.getStatusCode());
  }

  @Test
  void shouldThrow500WhenChunkFileIsMissing() {
    Song song = streamableSong(1L);
    Chunk chunk =
        Chunk.builder()
            .id(1L)
            .contentHash("h")
            .size(10)
            .storagePath("/nonexistent/path/chunk")
            .build();
    SongChunk sc = songChunk(song, chunk, 0);
    song.getChunks().add(sc);
    when(songRepository.findByFileHash("hash-1")).thenReturn(Optional.of(song));
    when(songChunkRepository.findWithChunkBySongAndOrderIndex(song, 0))
        .thenReturn(Optional.of(sc));

    ResponseStatusException ex =
        assertThrows(ResponseStatusException.class, () -> service.getSongChunk("hash-1", 0, 99L));
    assertEquals(HttpStatus.INTERNAL_SERVER_ERROR, ex.getStatusCode());
  }

  @Test
  void shouldThrow404WhenChunkAccessIsForbidden() {
    Song song = streamableSong(1L);
    song.setOwnerId(5L);
    when(songRepository.findByFileHash("hash-1")).thenReturn(Optional.of(song));

    ResponseStatusException ex =
        assertThrows(ResponseStatusException.class, () -> service.getSongChunk("hash-1", 0, 99L));
    assertEquals(HttpStatus.NOT_FOUND, ex.getStatusCode());
  }
}
