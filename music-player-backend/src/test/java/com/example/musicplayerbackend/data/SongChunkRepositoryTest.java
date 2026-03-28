package com.example.musicplayerbackend.data;

import com.example.musicplayerbackend.domain.*;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class SongChunkRepositoryTest extends BaseRepositoryTest {

    @Autowired
    SongChunkRepository songChunkRepository;

    @Autowired
    SongRepository songRepository;

    @Autowired
    ChunkRepository chunkRepository;

    @Autowired
    ArtistRepository artistRepository;

    @Autowired
    AlbumRepository albumRepository;

    private Song songA;
    private Song songB;
    private Chunk chunk;

    @BeforeEach
    void setUp() {
        Artist artist = artistRepository.save(Artist.builder().name("Artist").build());
        Album album = albumRepository.save(Album.builder().name("Album").artist(artist).build());

        songA = songRepository.save(Song.builder()
                .name("Song A").artist(artist).album(album)
                .songType(ContentType.STREAMABLE)
                .fileHash(UUID.randomUUID().toString())
                .build());

        songB = songRepository.save(Song.builder()
                .name("Song B").artist(artist).album(album)
                .songType(ContentType.STREAMABLE)
                .fileHash(UUID.randomUUID().toString())
                .build());

        chunk = chunkRepository.save(Chunk.builder()
                .contentHash("hash-" + UUID.randomUUID())
                .size(65536)
                .storagePath("/chunks/a.bin")
                .build());
    }

    @AfterEach
    void tearDown() {
        songChunkRepository.deleteAll();
        chunkRepository.deleteAll();
        songRepository.deleteAll();
        albumRepository.deleteAll();
        artistRepository.deleteAll();
    }

    @Test
    void shouldReturnTrueWhenSongChunkEntryExists() {
        songChunkRepository.save(SongChunk.builder()
                .song(songA).chunk(chunk).orderIndex(0).build());

        boolean exists = songChunkRepository.existsBySongAndOrderIndex(songA, 0);

        assertThat(exists).isTrue();
    }

    @Test
    void shouldReturnFalseWhenSongChunkEntryDoesNotExist() {
        boolean exists = songChunkRepository.existsBySongAndOrderIndex(songA, 0);

        assertThat(exists).isFalse();
    }

    @Test
    void shouldReturnFalseForWrongOrderIndex() {
        songChunkRepository.save(SongChunk.builder()
                .song(songA).chunk(chunk).orderIndex(0).build());

        boolean exists = songChunkRepository.existsBySongAndOrderIndex(songA, 1);

        assertThat(exists).isFalse();
    }

    @Test
    void shouldReturnFalseForDifferentSong() {
        songChunkRepository.save(SongChunk.builder()
                .song(songA).chunk(chunk).orderIndex(0).build());

        boolean exists = songChunkRepository.existsBySongAndOrderIndex(songB, 0);

        assertThat(exists).isFalse();
    }

    @Test
    void shouldPersistSongChunk() {
        SongChunk saved = songChunkRepository.save(SongChunk.builder()
                .song(songA).chunk(chunk).orderIndex(5).build());

        assertThat(saved.getId()).isNotNull().isPositive();
        assertThat(saved.getOrderIndex()).isEqualTo(5);
    }
}
