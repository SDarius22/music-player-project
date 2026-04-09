package com.example.musicplayerbackend.data;

import com.example.musicplayerbackend.domain.Artist;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;

import static org.assertj.core.api.Assertions.assertThat;

class ArtistRepositoryTest extends BaseRepositoryTest {

    @Autowired
    ArtistRepository artistRepository;

    @AfterEach
    void tearDown() {
        artistRepository.deleteAll();
    }

    @Test
    void shouldPersistArtist() {
        Artist saved = artistRepository.save(Artist.builder().name("Led Zeppelin").hash("led-hash").build());

        assertThat(saved.getId()).isNotNull().isPositive();
        assertThat(saved.getName()).isEqualTo("Led Zeppelin");
    }

    @Test
    void shouldReturnArtistWhenHashExists() {
        artistRepository.save(Artist.builder().name("Pink Floyd").hash("pink-hash").build());

        var found = artistRepository.findByHash("pink-hash");

        assertThat(found).isPresent();
        assertThat(found.get().getName()).isEqualTo("Pink Floyd");
    }

    @Test
    void shouldReturnEmptyWhenArtistHashNotFound() {
        var found = artistRepository.findByHash("ghost-hash");

        assertThat(found).isEmpty();
    }

    @Test
    void shouldMatchSubstringWhenSearchingArtistsByNameIgnoreCase() {
        artistRepository.save(Artist.builder().name("The Beatles").hash("beatles-hash").build());
        artistRepository.save(Artist.builder().name("The Rolling Stones").hash("stones-hash").build());
        artistRepository.save(Artist.builder().name("Radiohead").hash("radiohead-hash").build());

        Page<Artist> result = artistRepository.findAllByNameContainingIgnoreCase("the", PageRequest.of(0, 10));

        assertThat(result.getContent()).hasSizeGreaterThanOrEqualTo(2)
                .extracting(Artist::getName)
                .contains("The Beatles", "The Rolling Stones");
    }

    @Test
    void shouldBeCaseInsensitiveWhenSearchingArtistsByName() {
        artistRepository.save(Artist.builder().name("Nirvana").hash("nirvana-hash").build());

        Page<Artist> lower = artistRepository.findAllByNameContainingIgnoreCase("nirvana", PageRequest.of(0, 10));
        Page<Artist> upper = artistRepository.findAllByNameContainingIgnoreCase("NIRVANA", PageRequest.of(0, 10));

        assertThat(lower.getTotalElements()).isEqualTo(1);
        assertThat(upper.getTotalElements()).isEqualTo(1);
    }

    @Test
    void shouldReturnEmptyWhenNoArtistNameMatches() {
        artistRepository.save(Artist.builder().name("Metallica").hash("metallica-hash").build());

        Page<Artist> result = artistRepository.findAllByNameContainingIgnoreCase("zzznomatch", PageRequest.of(0, 10));

        assertThat(result).isEmpty();
    }

    @Test
    void shouldRespectPaginationWhenSearchingArtistsByName() {
        for (int i = 0; i < 6; i++) {
            artistRepository.save(Artist.builder().name("Band " + i).hash("band-hash-" + i).build());
        }

        Page<Artist> page0 = artistRepository.findAllByNameContainingIgnoreCase("Band", PageRequest.of(0, 3));
        Page<Artist> page1 = artistRepository.findAllByNameContainingIgnoreCase("Band", PageRequest.of(1, 3));

        assertThat(page0.getContent()).hasSize(3);
        assertThat(page0.getTotalElements()).isEqualTo(6);
        assertThat(page1.getContent()).hasSize(3);
    }
}
