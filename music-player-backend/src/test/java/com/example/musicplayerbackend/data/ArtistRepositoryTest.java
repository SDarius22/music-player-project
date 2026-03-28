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
        Artist saved = artistRepository.save(Artist.builder().name("Led Zeppelin").build());

        assertThat(saved.getId()).isNotNull().isPositive();
        assertThat(saved.getName()).isEqualTo("Led Zeppelin");
    }

    @Test
    void shouldReturnArtistWhenNameExists() {
        artistRepository.save(Artist.builder().name("Pink Floyd").build());

        var found = artistRepository.findByName("Pink Floyd");

        assertThat(found).isPresent();
        assertThat(found.get().getName()).isEqualTo("Pink Floyd");
    }

    @Test
    void shouldReturnEmptyWhenArtistNameNotFound() {
        var found = artistRepository.findByName("Ghost Artist");

        assertThat(found).isEmpty();
    }

    @Test
    void shouldMatchSubstringWhenSearchingArtistsByNameIgnoreCase() {
        artistRepository.save(Artist.builder().name("The Beatles").build());
        artistRepository.save(Artist.builder().name("The Rolling Stones").build());
        artistRepository.save(Artist.builder().name("Radiohead").build());

        Page<Artist> result = artistRepository.findAllByNameContainingIgnoreCase("the", PageRequest.of(0, 10));

        assertThat(result.getContent()).hasSizeGreaterThanOrEqualTo(2)
                .extracting(Artist::getName)
                .contains("The Beatles", "The Rolling Stones");
    }

    @Test
    void shouldBeCaseInsensitiveWhenSearchingArtistsByName() {
        artistRepository.save(Artist.builder().name("Nirvana").build());

        Page<Artist> lower = artistRepository.findAllByNameContainingIgnoreCase("nirvana", PageRequest.of(0, 10));
        Page<Artist> upper = artistRepository.findAllByNameContainingIgnoreCase("NIRVANA", PageRequest.of(0, 10));

        assertThat(lower.getTotalElements()).isEqualTo(1);
        assertThat(upper.getTotalElements()).isEqualTo(1);
    }

    @Test
    void shouldReturnEmptyWhenNoArtistNameMatches() {
        artistRepository.save(Artist.builder().name("Metallica").build());

        Page<Artist> result = artistRepository.findAllByNameContainingIgnoreCase("zzznomatch", PageRequest.of(0, 10));

        assertThat(result).isEmpty();
    }

    @Test
    void shouldRespectPaginationWhenSearchingArtistsByName() {
        for (int i = 0; i < 6; i++) {
            artistRepository.save(Artist.builder().name("Band " + i).build());
        }

        Page<Artist> page0 = artistRepository.findAllByNameContainingIgnoreCase("Band", PageRequest.of(0, 3));
        Page<Artist> page1 = artistRepository.findAllByNameContainingIgnoreCase("Band", PageRequest.of(1, 3));

        assertThat(page0.getContent()).hasSize(3);
        assertThat(page0.getTotalElements()).isEqualTo(6);
        assertThat(page1.getContent()).hasSize(3);
    }
}
