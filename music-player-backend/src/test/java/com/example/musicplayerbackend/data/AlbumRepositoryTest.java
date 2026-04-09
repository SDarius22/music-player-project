package com.example.musicplayerbackend.data;

import com.example.musicplayerbackend.data.projection.AlbumListProjection;
import com.example.musicplayerbackend.domain.Album;
import com.example.musicplayerbackend.domain.Artist;
import com.example.musicplayerbackend.domain.ContentType;
import com.example.musicplayerbackend.domain.Song;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;

import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;

class AlbumRepositoryTest extends BaseRepositoryTest {

    @Autowired
    AlbumRepository albumRepository;

    @Autowired
    ArtistRepository artistRepository;

    @Autowired
    SongRepository songRepository;

    private Artist artist;

    @BeforeEach
    void setUp() {
        artist = artistRepository.save(Artist.builder().name("Test Artist").hash("artist-hash").build());
    }

    @AfterEach
    void tearDown() {
        songRepository.deleteAll();
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

        Page<AlbumListProjection> result = albumRepository.findAllWithHashes("abbey", PageRequest.of(0, 10));

        assertThat(result.getContent()).hasSize(2)
                .extracting(AlbumListProjection::getName)
                .containsExactlyInAnyOrder("Abbey Road", "Abbey One");
    }

    @Test
    void shouldBeCaseInsensitiveWhenSearchingByName() {
        albumRepository.save(buildAlbum("Thriller"));

        Page<AlbumListProjection> lower = albumRepository.findAllWithHashes("thriller", PageRequest.of(0, 10));
        Page<AlbumListProjection> upper = albumRepository.findAllWithHashes("THRILLER", PageRequest.of(0, 10));
        Page<AlbumListProjection> mixed = albumRepository.findAllWithHashes("ThRiLlEr", PageRequest.of(0, 10));

        assertThat(lower.getTotalElements()).isEqualTo(1);
        assertThat(upper.getTotalElements()).isEqualTo(1);
        assertThat(mixed.getTotalElements()).isEqualTo(1);
    }

    @Test
    void shouldReturnAlbumProjectionWithHashAndArtistJson() {
        Album album = albumRepository.save(buildAlbum("The Wall"));

        Page<AlbumListProjection> result = albumRepository.findAllWithHashes("The Wall", PageRequest.of(0, 10));

        assertThat(result.getContent()).hasSize(1);
        AlbumListProjection projection = result.getContent().getFirst();
        assertThat(projection.getHash()).isEqualTo(album.getHash());
        assertThat(projection.getArtistHash()).isEqualTo(artist.getHash());
        assertThat(projection.getArtistName()).isEqualTo(artist.getName());
    }

    @Test
    void shouldSelectMainArtistByMostSongsWithinAlbum() {
        Artist mainArtist = artistRepository.save(Artist.builder().name("Main Artist").hash("main-hash").build());
        Artist featuredArtist = artistRepository.save(Artist.builder().name("Featured Artist").hash("featured-hash").build());
        Album album = albumRepository.save(Album.builder()
                .name("Ranked Album")
                .hash("album-ranked")
                .artists(Set.of(mainArtist, featuredArtist))
                .build());

        songRepository.save(Song.builder().name("Track 1").fileHash("main-track-1").songType(ContentType.STREAMABLE)
                .artist(mainArtist).album(album).discNumber(1).trackNumber(1).build());
        songRepository.save(Song.builder().name("Track 2").fileHash("main-track-2").songType(ContentType.STREAMABLE)
                .artist(mainArtist).album(album).discNumber(1).trackNumber(2).build());
        songRepository.save(Song.builder().name("Track 3").fileHash("featured-track-1").songType(ContentType.STREAMABLE)
                .artist(featuredArtist).album(album).discNumber(1).trackNumber(3).build());

        Page<AlbumListProjection> result = albumRepository.findAllWithHashes("Ranked Album", PageRequest.of(0, 10));

        assertThat(result.getContent()).hasSize(1);
        assertThat(result.getContent().getFirst().getArtistHash()).isEqualTo(mainArtist.getHash());
        assertThat(result.getContent().getFirst().getArtistName()).isEqualTo(mainArtist.getName());

    }

    @Test
    void shouldFindAlbumsByArtistName() {
        albumRepository.save(buildAlbum("Artist Search Album"));

        Page<AlbumListProjection> result = albumRepository.findAllWithHashes("test artist", PageRequest.of(0, 10));

        assertThat(result.getContent()).hasSize(1);
        assertThat(result.getContent().getFirst().getName()).isEqualTo("Artist Search Album");
    }

    @Test
    void shouldReturnEmptyWhenNoAlbumNameMatches() {
        albumRepository.save(buildAlbum("Something Blue"));

        Page<AlbumListProjection> result = albumRepository.findAllWithHashes("zzznomatch", PageRequest.of(0, 10));

        assertThat(result).isEmpty();
    }

    @Test
    void shouldRespectPaginationWhenSearchingAlbumsByName() {
        for (int i = 0; i < 5; i++) {
            albumRepository.save(buildAlbum("Page Album " + i));
        }

        Page<AlbumListProjection> page0 = albumRepository.findAllWithHashes("Page Album", PageRequest.of(0, 2));
        Page<AlbumListProjection> page1 = albumRepository.findAllWithHashes("Page Album", PageRequest.of(1, 2));

        assertThat(page0.getContent()).hasSize(2);
        assertThat(page0.getTotalElements()).isEqualTo(5);
        assertThat(page1.getContent()).hasSize(2);
    }
}
