package com.example.musicplayerbackend.service;

import com.example.musicplayerbackend.data.ArtistRepository;
import com.example.musicplayerbackend.domain.*;
import com.example.musicplayerbackend.mapper.ArtistMapper;
import com.example.musicplayerbackend.mapper.SortMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

import java.util.Base64;
import java.util.List;
import java.util.Optional;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class ArtistServiceTest {

    @Mock
    ArtistRepository artistRepository;

    @Mock
    SortMapper sortMapper;

    @Mock
    ArtistMapper artistMapper;

    @Mock
    SongEnrichmentService songEnrichmentService;

    ArtistService service;

    @BeforeEach
    void setUp() {
        service = new ArtistService(artistRepository, artistMapper, sortMapper, songEnrichmentService);
        org.mockito.Mockito.lenient().when(sortMapper.toSort(any())).thenReturn(org.springframework.data.domain.Sort.by("name"));
        org.mockito.Mockito.lenient().when(songEnrichmentService.enrich(anyList(), any())).thenAnswer(inv -> {
            List<Song> songs = inv.getArgument(0);
            return songs.stream().map(s -> {
                SongDto dto = new SongDto();
                dto.setFileHash(s.getFileHash());
                dto.setName(s.getName());
                return dto;
            }).toList();
        });

        // Keep service tests independent from generated mapper impl classes.
        org.mockito.Mockito.lenient().when(artistMapper.toExpandedDto(any())).thenAnswer(invocation -> {
            Artist artist = invocation.getArgument(0);
            ArtistExpandedDto dto = new ArtistExpandedDto();
            dto.setHash(artist.getHash());
            dto.setName(artist.getName());
            var songs = artist.getSongs();
            dto.setSongFileHashes(songs == null ? List.of() : songs.stream().map(Song::getFileHash).toList());
            return dto;
        });

        org.mockito.Mockito.lenient().when(artistMapper.toDetailDto(any())).thenAnswer(invocation -> {
            Artist artist = invocation.getArgument(0);
            ArtistDetailDto dto = new ArtistDetailDto();
            dto.setHash(artist.getHash());
            dto.setName(artist.getName());
            var songs = artist.getSongs();
            dto.setSongs(songs == null ? List.of() : songs.stream().map(song -> {
                SongDto songDto = new SongDto();
                songDto.setFileHash(song.getFileHash());
                songDto.setName(song.getName());
                return songDto;
            }).toList());
            return dto;
        });
    }

    // ── getArtists ───────────────────────────────────────────────────────────

    @Test
    void shouldReturnPagedArtistResults() {
        Song song = Song.builder().name("Track 1").fileHash("h1").songType(ContentType.STREAMABLE).build();
        Artist artist = Artist.builder()
                .id(1L)
                .hash("artist-hash")
                .name("Beatles")
                .songs(List.of(song))
                .build();
        when(artistRepository.findAllByNameContainingIgnoreCase(eq(""), any())).thenReturn(new PageImpl<>(List.of(artist)));

        ArtistPageDto result = service.getArtists(null, 0, 20, null);

        assertEquals(1, result.getContent().size());
        assertEquals("artist-hash", result.getContent().getFirst().getHash());
        assertEquals("Beatles", result.getContent().getFirst().getName());
    }

    @Test
    void shouldPassBlankArtistQueryAsEmpty() {
        when(artistRepository.findAllByNameContainingIgnoreCase(eq(""), any())).thenReturn(Page.empty());
        service.getArtists("  ", 0, 20, null);
        verify(artistRepository).findAllByNameContainingIgnoreCase(eq(""), any());
    }

    @Test
    void shouldPassNonBlankArtistQueryThrough() {
        when(artistRepository.findAllByNameContainingIgnoreCase(eq("rock"), any())).thenReturn(Page.empty());
        service.getArtists("rock", 0, 20, null);
        verify(artistRepository).findAllByNameContainingIgnoreCase(eq("rock"), any());
    }

    @Test
    void shouldSortArtistsAscendingWhenExplicitAscProvided() {
        when(sortMapper.toSort("name,asc")).thenReturn(
                org.springframework.data.domain.Sort.by(org.springframework.data.domain.Sort.Order.asc("name")));
        when(artistRepository.findAllByNameContainingIgnoreCase(any(),
                argThat(p -> p.getSort().getOrderFor("name") != null
                        && p.getSort().getOrderFor("name").isAscending())))
                .thenReturn(Page.empty());
        service.getArtists(null, 0, 20, "name,asc");
        verify(artistRepository).findAllByNameContainingIgnoreCase(any(),
                argThat(p -> p.getSort().getOrderFor("name") != null
                        && p.getSort().getOrderFor("name").isAscending()));
    }

    @Test
    void shouldSortArtistsDescending() {
        when(sortMapper.toSort("name,desc")).thenReturn(
                org.springframework.data.domain.Sort.by(org.springframework.data.domain.Sort.Order.desc("name")));
        when(artistRepository.findAllByNameContainingIgnoreCase(any(),
                argThat(p -> p.getSort().getOrderFor("name") != null
                        && p.getSort().getOrderFor("name").isDescending())))
                .thenReturn(Page.empty());
        service.getArtists(null, 0, 20, "name,desc");
        verify(artistRepository).findAllByNameContainingIgnoreCase(any(),
                argThat(p -> p.getSort().getOrderFor("name") != null
                        && p.getSort().getOrderFor("name").isDescending()));
    }

    @Test
    void shouldSplitHashesFromArtistSongs() {
        Song song1 = Song.builder().name("Track 1").fileHash("h1").songType(ContentType.STREAMABLE).build();
        Song song2 = Song.builder().name("Track 2").fileHash("h2").songType(ContentType.STREAMABLE).build();
        Artist artist = Artist.builder().id(1L).hash("artist-hash").name("Beatles").songs(List.of(song1, song2)).build();
        when(artistRepository.findAllByNameContainingIgnoreCase(eq(""), any())).thenReturn(new PageImpl<>(List.of(artist)));

        ArtistPageDto result = service.getArtists(null, 0, 20, null);

        assertEquals(List.of("h1", "h2"), result.getContent().getFirst().getSongFileHashes());
    }

    @Test
    void shouldReturnEmptyHashesWhenArtistSongsAreEmpty() {
        Artist artist = Artist.builder().id(1L).hash("artist-hash").name("Beatles").songs(List.of()).build();
        when(artistRepository.findAllByNameContainingIgnoreCase(eq(""), any())).thenReturn(new PageImpl<>(List.of(artist)));

        ArtistPageDto result = service.getArtists(null, 0, 20, null);

        assertTrue(result.getContent().getFirst().getSongFileHashes().isEmpty());
    }

    // ── getArtistByHash ──────────────────────────────────────────────────────

    @Test
    void shouldReturnArtistDetailDto() {
        Artist artist = Artist.builder().id(1L).hash("beatles-hash").name("Beatles").songs(List.of()).build();
        when(artistRepository.findByHash("beatles-hash")).thenReturn(Optional.of(artist));

        ArtistDetailDto result = service.getArtistByHash("beatles-hash", 1L);

        assertEquals("beatles-hash", result.getHash());
        assertEquals("Beatles", result.getName());
        assertTrue(result.getSongs().isEmpty());
    }

    @Test
    void shouldThrow404WhenArtistByHashNotFound() {
        when(artistRepository.findByHash("missing-hash")).thenReturn(Optional.empty());
        ResponseStatusException ex = assertThrows(ResponseStatusException.class,
                () -> service.getArtistByHash("missing-hash", 1L));
        assertEquals(HttpStatus.NOT_FOUND, ex.getStatusCode());
    }

    @Test
    void shouldMapSongsWhenGettingArtistById() {
        Song song = Song.builder().id(10L).name("Come Together").fileHash("hash1")
                .songType(ContentType.STREAMABLE).build();
        Artist artist = Artist.builder().id(1L).hash("beatles-hash").name("Beatles").songs(List.of(song)).build();
        when(artistRepository.findByHash("beatles-hash")).thenReturn(Optional.of(artist));

        ArtistDetailDto result = service.getArtistByHash("beatles-hash", 1L);

        assertEquals(1, result.getSongs().size());
        assertEquals("hash1", result.getSongs().getFirst().getFileHash());
    }

    @Test
    void shouldReturnEmptySongsWhenArtistSongsAreNull() {
        Artist artist = Artist.builder().id(1L).hash("solo-hash").name("Solo").songs(null).build();
        when(artistRepository.findByHash("solo-hash")).thenReturn(Optional.of(artist));

        ArtistDetailDto result = service.getArtistByHash("solo-hash", 1L);

        assertTrue(result.getSongs().isEmpty());
    }

    // ── getArtistCover ───────────────────────────────────────────────────────

    @Test
    void shouldThrow404WhenArtistCoverHasNoAlbums() {
        Artist artist = Artist.builder().id(1L).hash("artist-hash").name("Artist").albums(Set.of()).build();
        when(artistRepository.findByHash("artist-hash")).thenReturn(Optional.of(artist));
        assertThrows(ResponseStatusException.class, () -> service.getArtistCover("artist-hash"));
    }

    @Test
    void shouldThrow404WhenAllArtistAlbumsHaveNoImage() {
        Album album = Album.builder().id(1L).name("No Cover").coverImage(null).build();
        Artist artist = Artist.builder().id(1L).hash("artist-hash").name("Artist").albums(Set.of(album)).build();
        when(artistRepository.findByHash("artist-hash")).thenReturn(Optional.of(artist));
        assertThrows(ResponseStatusException.class, () -> service.getArtistCover("artist-hash"));
    }

    @Test
    void shouldReturnArtistCoverFromFirstAlbumWithImage() {
        byte[] img = "coverdata".getBytes();
        Album album1 = Album.builder().id(1L).coverImage(null).build();
        Album album2 = Album.builder().id(2L)
                .coverImage(Base64.getEncoder().encodeToString(img)).build();
        Artist artist = Artist.builder().id(1L).hash("artist-hash").name("Artist")
                .albums(Set.of(album1, album2)).build();
        when(artistRepository.findByHash("artist-hash")).thenReturn(Optional.of(artist));

        assertArrayEquals(img, service.getArtistCover("artist-hash"));
    }

    @Test
    void shouldThrow404WhenArtistCoverArtistNotFound() {
        when(artistRepository.findByHash("missing-hash")).thenReturn(Optional.empty());
        assertThrows(ResponseStatusException.class, () -> service.getArtistCover("missing-hash"));
    }

    @Test
    void shouldThrow404WhenAllArtistAlbumsHaveBlankImage() {
        Album album = Album.builder().id(1L).name("Album").coverImage("   ").build();
        Artist artist = Artist.builder().id(1L).hash("artist-hash").name("Artist").albums(Set.of(album)).build();
        when(artistRepository.findByHash("artist-hash")).thenReturn(Optional.of(artist));
        ResponseStatusException ex = assertThrows(ResponseStatusException.class,
                () -> service.getArtistCover("artist-hash"));
        assertEquals(HttpStatus.NOT_FOUND, ex.getStatusCode());
    }

    @Test
    void shouldThrow404WhenArtistAlbumsAreNull() {
        Artist artist = Artist.builder().id(1L).hash("artist-hash").name("Artist").albums(null).build();
        when(artistRepository.findByHash("artist-hash")).thenReturn(Optional.of(artist));
        assertThrows(ResponseStatusException.class, () -> service.getArtistCover("artist-hash"));
    }
}
