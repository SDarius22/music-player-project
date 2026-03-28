package com.example.musicplayerbackend.data;

import com.example.musicplayerbackend.domain.Album;
import com.example.musicplayerbackend.domain.Artist;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;

import static org.assertj.core.api.Assertions.assertThat;

class AlbumRepositoryTest extends BaseRepositoryTest {

    @Autowired
    AlbumRepository albumRepository;

    @Autowired
    ArtistRepository artistRepository;

    private Artist artist;

    @BeforeEach
    void setUp() {
        artist = artistRepository.save(Artist.builder().name("Test Artist").build());
    }

    @AfterEach
    void tearDown() {
        albumRepository.deleteAll();
        artistRepository.deleteAll();
    }

    private Album buildAlbum(String name) {
        return Album.builder().name(name).artist(artist).build();
    }

    @Test
    void shouldPersistAlbum() {
        Album saved = albumRepository.save(buildAlbum("Dark Side"));

        assertThat(saved.getId()).isNotNull().isPositive();
        assertThat(saved.getName()).isEqualTo("Dark Side");
    }

    @Test
    void shouldReturnAlbumWhenNameExists() {
        albumRepository.save(buildAlbum("Rumours"));

        var found = albumRepository.findByName("Rumours");

        assertThat(found).isPresent();
        assertThat(found.get().getName()).isEqualTo("Rumours");
    }

    @Test
    void shouldReturnEmptyWhenAlbumNameNotFound() {
        var found = albumRepository.findByName("NonExistentAlbum");

        assertThat(found).isEmpty();
    }

    @Test
    void shouldMatchSubstringWhenSearchingByNameIgnoreCase() {
        albumRepository.save(buildAlbum("Abbey Road"));
        albumRepository.save(buildAlbum("Abbey One"));
        albumRepository.save(buildAlbum("Unrelated"));

        Page<Album> result = albumRepository.findAllByNameContainingIgnoreCase("abbey", PageRequest.of(0, 10));

        assertThat(result.getContent()).hasSize(2)
                .extracting(Album::getName)
                .containsExactlyInAnyOrder("Abbey Road", "Abbey One");
    }

    @Test
    void shouldBeCaseInsensitiveWhenSearchingByName() {
        albumRepository.save(buildAlbum("Thriller"));

        Page<Album> lower = albumRepository.findAllByNameContainingIgnoreCase("thriller", PageRequest.of(0, 10));
        Page<Album> upper = albumRepository.findAllByNameContainingIgnoreCase("THRILLER", PageRequest.of(0, 10));
        Page<Album> mixed = albumRepository.findAllByNameContainingIgnoreCase("ThRiLlEr", PageRequest.of(0, 10));

        assertThat(lower.getTotalElements()).isEqualTo(1);
        assertThat(upper.getTotalElements()).isEqualTo(1);
        assertThat(mixed.getTotalElements()).isEqualTo(1);
    }

    @Test
    void shouldReturnEmptyWhenNoAlbumNameMatches() {
        albumRepository.save(buildAlbum("Something Blue"));

        Page<Album> result = albumRepository.findAllByNameContainingIgnoreCase("zzznomatch", PageRequest.of(0, 10));

        assertThat(result).isEmpty();
    }

    @Test
    void shouldRespectPaginationWhenSearchingAlbumsByName() {
        for (int i = 0; i < 5; i++) {
            albumRepository.save(buildAlbum("Page Album " + i));
        }

        Page<Album> page0 = albumRepository.findAllByNameContainingIgnoreCase("Page Album", PageRequest.of(0, 2));
        Page<Album> page1 = albumRepository.findAllByNameContainingIgnoreCase("Page Album", PageRequest.of(1, 2));

        assertThat(page0.getContent()).hasSize(2);
        assertThat(page0.getTotalElements()).isEqualTo(5);
        assertThat(page1.getContent()).hasSize(2);
    }
}
