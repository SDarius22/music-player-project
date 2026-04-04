package com.example.musicplayerbackend.service;

import com.example.musicplayerbackend.data.SongRepository;
import com.example.musicplayerbackend.domain.*;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.api.io.TempDir;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

import java.io.File;
import java.io.FileOutputStream;
import java.nio.file.Path;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class StreamingServiceTest {

    @Mock
    SongRepository songRepository;

    @TempDir
    Path tempDir;

    StreamingService service;

    @BeforeEach
    void setUp() {
        service = new StreamingService(songRepository);
    }

    private Song streamableSong(long id) {
        Song song = Song.builder().id(id).name("Song " + id)
                .songType(ContentType.STREAMABLE).fileHash("hash-" + id).build();
        song.setChunks(new java.util.ArrayList<>());
        return song;
    }

    private Chunk chunkWithFile(byte[] data) throws Exception {
        File f = tempDir.resolve("chunk-" + System.nanoTime()).toFile();
        try (FileOutputStream fos = new FileOutputStream(f)) {
            fos.write(data);
        }
        return Chunk.builder().id(1L).contentHash("h").size(data.length)
                .storagePath(f.getAbsolutePath()).build();
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
    void shouldThrow403WhenManifestPrivateSongOwnedByOther() {
        Song song = streamableSong(1L);
        song.setOwnerId(5L); // owned by user 5
        when(songRepository.findByFileHash("hash-1")).thenReturn(Optional.of(song));

        ResponseStatusException ex = assertThrows(ResponseStatusException.class,
                () -> service.getSongManifest("hash-1", 99L)); // user 99 requests
        assertEquals(HttpStatus.FORBIDDEN, ex.getStatusCode());
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
        Chunk c2 = Chunk.builder().id(2L).contentHash("h2").size(500).storagePath(
                tempDir.resolve("c2").toAbsolutePath().toString()).build();
        // write c2 file
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
        song.getChunks().add(songChunk(song, chunk, 0));
        when(songRepository.findByFileHash("hash-1")).thenReturn(Optional.of(song));

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

        ResponseStatusException ex = assertThrows(ResponseStatusException.class,
                () -> service.getSongChunk("hash-1", 5, 99L));
        assertEquals(HttpStatus.BAD_REQUEST, ex.getStatusCode());
    }

    @Test
    void shouldThrowBadRequestWhenChunkIndexIsNegative() throws Exception {
        Song song = streamableSong(1L);
        Chunk chunk = chunkWithFile("x".getBytes());
        song.getChunks().add(songChunk(song, chunk, 0));
        when(songRepository.findByFileHash("hash-1")).thenReturn(Optional.of(song));

        ResponseStatusException ex = assertThrows(ResponseStatusException.class,
                () -> service.getSongChunk("hash-1", -1, 99L));
        assertEquals(HttpStatus.BAD_REQUEST, ex.getStatusCode());
    }

    @Test
    void shouldThrow500WhenChunkFileIsMissing() {
        Song song = streamableSong(1L);
        Chunk chunk = Chunk.builder().id(1L).contentHash("h").size(10)
                .storagePath("/nonexistent/path/chunk").build();
        song.getChunks().add(songChunk(song, chunk, 0));
        when(songRepository.findByFileHash("hash-1")).thenReturn(Optional.of(song));

        ResponseStatusException ex = assertThrows(ResponseStatusException.class,
                () -> service.getSongChunk("hash-1", 0, 99L));
        assertEquals(HttpStatus.INTERNAL_SERVER_ERROR, ex.getStatusCode());
    }

    @Test
    void shouldThrow403WhenChunkAccessIsForbidden() {
        Song song = streamableSong(1L);
        song.setOwnerId(5L);
        when(songRepository.findByFileHash("hash-1")).thenReturn(Optional.of(song));

        assertThrows(ResponseStatusException.class, () -> service.getSongChunk("hash-1", 0, 99L));
    }

    @Test
    void shouldReturnEmptyPrefixResourceWhenNoChunks() {
        Song song = streamableSong(1L);
        when(songRepository.findByFileHash("hash-1")).thenReturn(Optional.of(song));

        Resource resource = service.getSongPrefix("hash-1", 100, 99L);

        assertNotNull(resource);
    }

    @Test
    void shouldReturnPrefixWhenChunksPresent() throws Exception {
        Song song = streamableSong(1L);
        byte[] data = new byte[1000];
        Chunk chunk = chunkWithFile(data);
        song.getChunks().add(songChunk(song, chunk, 0));
        when(songRepository.findByFileHash("hash-1")).thenReturn(Optional.of(song));

        Resource resource = service.getSongPrefix("hash-1", 500, 99L);

        assertNotNull(resource);
    }

    @Test
    void shouldThrow403WhenPrefixAccessIsForbidden() {
        Song song = streamableSong(1L);
        song.setOwnerId(5L);
        when(songRepository.findByFileHash("hash-1")).thenReturn(Optional.of(song));

        assertThrows(ResponseStatusException.class, () -> service.getSongPrefix("hash-1", 100, 99L));
    }

    @Test
    void shouldUseDefaultPrefixBytesWhenZero() throws Exception {
        Song song = streamableSong(1L);
        byte[] data = new byte[100];
        Chunk chunk = chunkWithFile(data);
        song.getChunks().add(songChunk(song, chunk, 0));
        when(songRepository.findByFileHash("hash-1")).thenReturn(Optional.of(song));

        // 0 → falls to default (512000), data (100) <= 512000 → plain ByteArrayResource
        Resource resource = service.getSongPrefix("hash-1", 0, 99L);

        assertNotNull(resource);
    }

    @Test
    void shouldUseDefaultPrefixBytesWhenNegative() throws Exception {
        Song song = streamableSong(1L);
        byte[] data = new byte[100];
        Chunk chunk = chunkWithFile(data);
        song.getChunks().add(songChunk(song, chunk, 0));
        when(songRepository.findByFileHash("hash-1")).thenReturn(Optional.of(song));

        // negative → falls to default (512000), data (100) <= 512000 → plain ByteArrayResource
        Resource resource = service.getSongPrefix("hash-1", -1, 99L);

        assertNotNull(resource);
    }

    @Test
    void shouldReturnPlainResourceWhenBufferDoesNotExceedBytesNeeded() throws Exception {
        Song song = streamableSong(1L);
        // data smaller than bytesNeeded → fullBuffer.length <= bytesNeeded → plain ByteArrayResource
        byte[] data = new byte[100];
        Chunk chunk = chunkWithFile(data);
        song.getChunks().add(songChunk(song, chunk, 0));
        when(songRepository.findByFileHash("hash-1")).thenReturn(Optional.of(song));

        Resource resource = service.getSongPrefix("hash-1", 1000, 99L);

        assertNotNull(resource);
        assertNull(resource.getFilename()); // plain ByteArrayResource has no filename
    }

    @Test
    void shouldReturnNamedResourceWhenBufferExceedsBytesNeeded() throws Exception {
        Song song = streamableSong(1L);
        // 1000 bytes of data, bytesNeeded = 100 → fullBuffer.length (1000) > bytesNeeded (100) → named resource
        byte[] data = new byte[1000];
        Chunk chunk = chunkWithFile(data);
        song.getChunks().add(songChunk(song, chunk, 0));
        when(songRepository.findByFileHash("hash-1")).thenReturn(Optional.of(song));

        Resource resource = service.getSongPrefix("hash-1", 100, 99L);

        assertEquals("prefix.mp3", resource.getFilename());
    }

    @Test
    void shouldUseDefaultPrefixBytesWhenNull() throws Exception {
        Song song = streamableSong(1L);
        byte[] data = new byte[512];
        Chunk chunk = chunkWithFile(data);
        song.getChunks().add(songChunk(song, chunk, 0));
        when(songRepository.findByFileHash("hash-1")).thenReturn(Optional.of(song));

        Resource resource = service.getSongPrefix("hash-1", null, 99L);

        assertNotNull(resource);
    }
    
    @Test
    void shouldThrow500WhenFullStreamChunkFileIsMissing() {
        Song song = streamableSong(1L);
        Chunk chunk = Chunk.builder().id(1L).contentHash("h").size(10)
                .storagePath("/nonexistent/path/missing-chunk").build();
        song.getChunks().add(songChunk(song, chunk, 0));
        when(songRepository.findByFileHash("hash-1")).thenReturn(Optional.of(song));

        ResponseStatusException ex = assertThrows(ResponseStatusException.class,
                () -> service.getFullStream("hash-1", 99L));
        assertEquals(HttpStatus.INTERNAL_SERVER_ERROR, ex.getStatusCode());
    }

    @Test
    void shouldThrow403WhenFullStreamAccessIsForbidden() {
        Song song = streamableSong(1L);
        song.setOwnerId(5L);
        when(songRepository.findByFileHash("hash-1")).thenReturn(Optional.of(song));

        assertThrows(ResponseStatusException.class, () -> service.getFullStream("hash-1", 99L));
    }

    @Test
    void shouldThrow404WhenFullStreamSongNotFound() {
        when(songRepository.findByFileHash("hash-1")).thenReturn(Optional.empty());
        assertThrows(ResponseStatusException.class, () -> service.getFullStream("hash-1", 1L));
    }

    @Test
    void shouldReturnFullStreamResource() throws Exception {
        Song song = streamableSong(1L);
        Chunk chunk = chunkWithFile("audio".getBytes());
        song.getChunks().add(songChunk(song, chunk, 0));
        when(songRepository.findByFileHash("hash-1")).thenReturn(Optional.of(song));

        Resource resource = service.getFullStream("hash-1", 99L);

        assertNotNull(resource);
    }

    @Test
    void shouldConcatenateMultipleChunksForFullStream() throws Exception {
        Song song = streamableSong(1L);
        Chunk c1 = chunkWithFile("part1".getBytes());
        Chunk c2 = chunkWithFile("part2".getBytes());
        song.getChunks().add(songChunk(song, c1, 0));
        song.getChunks().add(songChunk(song, c2, 1));
        when(songRepository.findByFileHash("hash-1")).thenReturn(Optional.of(song));

        Resource resource = service.getFullStream("hash-1", 99L);

        byte[] bytes = resource.getInputStream().readAllBytes();
        assertArrayEquals("part1part2".getBytes(), bytes);
    }
}
