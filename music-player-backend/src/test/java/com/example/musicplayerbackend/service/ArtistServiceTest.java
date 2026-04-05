package com.example.musicplayerbackend.service;

import com.example.musicplayerbackend.data.ArtistRepository;
import com.example.musicplayerbackend.data.projection.ArtistListProjection;
import com.example.musicplayerbackend.domain.*;
import com.example.musicplayerbackend.mapper.AlbumMapper;
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

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class ArtistServiceTest {

    @Mock ArtistRepository artistRepository;
    @Mock AlbumMapper albumMapper;
    @Mock ArtistMapper artistMapper;
    @Mock SortMapper sortMapper;

    ArtistService service;

    @BeforeEach
    void setUp() {
        service = new ArtistService(artistRepository, albumMapper, artistMapper, sortMapper);
        org.mockito.Mockito.lenient().when(sortMapper.toSort(any())).thenReturn(org.springframework.data.domain.Sort.by("name"));
    }

    // ── getArtists ───────────────────────────────────────────────────────────

    @Test
    void shouldReturnPagedArtistResults() {
        ArtistListProjection proj = mock(ArtistListProjection.class);
        when(proj.getSongFileHashesCsv()).thenReturn(null);
        ArtistListDto listDto = new ArtistListDto();
        listDto.setId(1L);
        listDto.setName("Beatles");
        when(artistRepository.findAllWithHashes(eq(""), any())).thenReturn(new PageImpl<>(List.of(proj)));
        when(artistMapper.toListDto(proj)).thenReturn(listDto);

        ArtistPageDto result = service.getArtists(null, 0, 20, null);

        assertEquals(1, result.getContent().size());
        assertEquals(1L, result.getContent().getFirst().getId());
        assertEquals("Beatles", result.getContent().getFirst().getName());
    }

    @Test
    void shouldPassBlankArtistQueryAsEmpty() {
        when(artistRepository.findAllWithHashes(eq(""), any())).thenReturn(Page.empty());
        service.getArtists("  ", 0, 20, null);
        verify(artistRepository).findAllWithHashes(eq(""), any());
    }

    @Test
    void shouldPassNonBlankArtistQueryThrough() {
        when(artistRepository.findAllWithHashes(eq("rock"), any())).thenReturn(Page.empty());
        service.getArtists("rock", 0, 20, null);
        verify(artistRepository).findAllWithHashes(eq("rock"), any());
    }

    @Test
    void shouldSortArtistsAscendingWhenExplicitAscProvided() {
        when(sortMapper.toSort("name,asc")).thenReturn(
                org.springframework.data.domain.Sort.by(org.springframework.data.domain.Sort.Order.asc("name")));
        when(artistRepository.findAllWithHashes(any(),
                argThat(p -> p.getSort().getOrderFor("name") != null
                        && p.getSort().getOrderFor("name").isAscending())))
                .thenReturn(Page.empty());
        service.getArtists(null, 0, 20, "name,asc");
        verify(artistRepository).findAllWithHashes(any(),
                argThat(p -> p.getSort().getOrderFor("name") != null
                        && p.getSort().getOrderFor("name").isAscending()));
    }

    @Test
    void shouldSortArtistsDescending() {
        when(sortMapper.toSort("name,desc")).thenReturn(
                org.springframework.data.domain.Sort.by(org.springframework.data.domain.Sort.Order.desc("name")));
        when(artistRepository.findAllWithHashes(any(),
                argThat(p -> p.getSort().getOrderFor("name") != null
                        && p.getSort().getOrderFor("name").isDescending())))
                .thenReturn(Page.empty());
        service.getArtists(null, 0, 20, "name,desc");
        verify(artistRepository).findAllWithHashes(any(),
                argThat(p -> p.getSort().getOrderFor("name") != null
                        && p.getSort().getOrderFor("name").isDescending()));
    }

    @Test
    void shouldSplitCsvHashesFromProjection() {
        ArtistListProjection proj = mock(ArtistListProjection.class);
        when(proj.getSongFileHashesCsv()).thenReturn("h1,h2");
        ArtistListDto listDto = new ArtistListDto();
        when(artistRepository.findAllWithHashes(eq(""), any())).thenReturn(new PageImpl<>(List.of(proj)));
        when(artistMapper.toListDto(proj)).thenReturn(listDto);

        ArtistPageDto result = service.getArtists(null, 0, 20, null);

        assertEquals(List.of("h1", "h2"), result.getContent().getFirst().getSongFileHashes());
    }

    @Test
    void shouldReturnEmptyHashesWhenProjectionCsvIsNull() {
        ArtistListProjection proj = mock(ArtistListProjection.class);
        when(proj.getSongFileHashesCsv()).thenReturn(null);
        ArtistListDto listDto = new ArtistListDto();
        when(artistRepository.findAllWithHashes(eq(""), any())).thenReturn(new PageImpl<>(List.of(proj)));
        when(artistMapper.toListDto(proj)).thenReturn(listDto);

        ArtistPageDto result = service.getArtists(null, 0, 20, null);

        assertTrue(result.getContent().getFirst().getSongFileHashes().isEmpty());
    }

    // ── getArtistById ────────────────────────────────────────────────────────

    @Test
    void shouldReturnArtistDetailDto() {
        Artist artist = Artist.builder().id(1L).name("Beatles").albums(List.of()).build();
        when(artistRepository.findById(1L)).thenReturn(Optional.of(artist));

        ArtistDetailDto result = service.getArtistById(1L);

        assertEquals(1L, result.getId());
        assertEquals("Beatles", result.getName());
        assertTrue(result.getAlbums().isEmpty());
    }

    @Test
    void shouldThrow404WhenArtistByIdNotFound() {
        when(artistRepository.findById(99L)).thenReturn(Optional.empty());
        ResponseStatusException ex = assertThrows(ResponseStatusException.class,
                () -> service.getArtistById(99L));
        assertEquals(HttpStatus.NOT_FOUND, ex.getStatusCode());
    }

    @Test
    void shouldMapAlbumsWhenGettingArtistById() {
        Album album = Album.builder().id(10L).name("Abbey Road").build();
        AlbumDto albumDto = new AlbumDto();
        albumDto.setId(10L);
        Artist artist = Artist.builder().id(1L).name("Beatles").albums(List.of(album)).build();
        when(artistRepository.findById(1L)).thenReturn(Optional.of(artist));
        when(albumMapper.toDto(album)).thenReturn(albumDto);

        ArtistDetailDto result = service.getArtistById(1L);

        assertEquals(1, result.getAlbums().size());
        assertEquals(10L, result.getAlbums().getFirst().getId());
    }

    @Test
    void shouldReturnEmptyAlbumsWhenArtistAlbumsAreNull() {
        Artist artist = Artist.builder().id(1L).name("Solo").albums(null).build();
        when(artistRepository.findById(1L)).thenReturn(Optional.of(artist));

        ArtistDetailDto result = service.getArtistById(1L);

        assertTrue(result.getAlbums().isEmpty());
    }

    // ── getArtistCover ───────────────────────────────────────────────────────

    @Test
    void shouldThrow404WhenArtistCoverHasNoAlbums() {
        Artist artist = Artist.builder().id(1L).name("Artist").albums(List.of()).build();
        when(artistRepository.findById(1L)).thenReturn(Optional.of(artist));
        assertThrows(ResponseStatusException.class, () -> service.getArtistCover(1L));
    }

    @Test
    void shouldThrow404WhenAllArtistAlbumsHaveNoImage() {
        Album album = Album.builder().id(1L).name("No Cover").coverImage(null).build();
        Artist artist = Artist.builder().id(1L).name("Artist").albums(List.of(album)).build();
        when(artistRepository.findById(1L)).thenReturn(Optional.of(artist));
        assertThrows(ResponseStatusException.class, () -> service.getArtistCover(1L));
    }

    @Test
    void shouldReturnArtistCoverFromFirstAlbumWithImage() {
        byte[] img = "coverdata".getBytes();
        Album album1 = Album.builder().id(1L).coverImage(null).build();
        Album album2 = Album.builder().id(2L)
                .coverImage(Base64.getEncoder().encodeToString(img)).build();
        Artist artist = Artist.builder().id(1L).name("Artist")
                .albums(List.of(album1, album2)).build();
        when(artistRepository.findById(1L)).thenReturn(Optional.of(artist));

        assertArrayEquals(img, service.getArtistCover(1L));
    }

    @Test
    void shouldThrow404WhenArtistCoverArtistNotFound() {
        when(artistRepository.findById(1L)).thenReturn(Optional.empty());
        assertThrows(ResponseStatusException.class, () -> service.getArtistCover(1L));
    }

    @Test
    void shouldThrow404WhenAllArtistAlbumsHaveBlankImage() {
        Album album = Album.builder().id(1L).name("Album").coverImage("   ").build();
        Artist artist = Artist.builder().id(1L).name("Artist").albums(List.of(album)).build();
        when(artistRepository.findById(1L)).thenReturn(Optional.of(artist));
        ResponseStatusException ex = assertThrows(ResponseStatusException.class,
                () -> service.getArtistCover(1L));
        assertEquals(HttpStatus.NOT_FOUND, ex.getStatusCode());
    }

    @Test
    void shouldThrow404WhenArtistAlbumsAreNull() {
        Artist artist = Artist.builder().id(1L).name("Artist").albums(null).build();
        when(artistRepository.findById(1L)).thenReturn(Optional.of(artist));
        assertThrows(ResponseStatusException.class, () -> service.getArtistCover(1L));
    }
}
