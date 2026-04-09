package com.example.musicplayerbackend.service;

import com.example.musicplayerbackend.data.AlbumRepository;
import com.example.musicplayerbackend.data.projection.AlbumListProjection;
import com.example.musicplayerbackend.domain.*;
import com.example.musicplayerbackend.helpers.CoverDecoder;
import com.example.musicplayerbackend.mapper.AlbumMapper;
import com.example.musicplayerbackend.mapper.AlbumMapperImpl;
import com.example.musicplayerbackend.mapper.ArtistMapperImpl;
import com.example.musicplayerbackend.mapper.SortMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.http.HttpStatus;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.web.server.ResponseStatusException;

import java.util.Base64;
import java.util.List;
import java.util.Optional;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class AlbumServiceTest {

    @Mock
    AlbumRepository albumRepository;

    @Mock
    SortMapper sortMapper;

    AlbumMapper albumMapper;


    AlbumService service;

    @BeforeEach
    void setUp() {
        AlbumMapperImpl mapper = new AlbumMapperImpl();
        ReflectionTestUtils.setField(mapper, "artistMapper", new ArtistMapperImpl());
        albumMapper = mapper;

        service = new AlbumService(albumRepository, albumMapper, sortMapper);
        org.mockito.Mockito.lenient().when(sortMapper.toSort(any())).thenReturn(org.springframework.data.domain.Sort.by("name"));
    }

    // ── CoverDecoder ─────────────────────────────────────────────────────────

    @Test
    void shouldThrowNotFoundWhenDecodeCoverImageIsNull() {
        ResponseStatusException ex = assertThrows(ResponseStatusException.class,
                () -> CoverDecoder.decodeCoverImage(null));
        assertEquals(HttpStatus.NOT_FOUND, ex.getStatusCode());
    }

    @Test
    void shouldThrowNotFoundWhenDecodeCoverImageIsBlank() {
        assertThrows(ResponseStatusException.class, () -> CoverDecoder.decodeCoverImage("   "));
    }

    @Test
    void shouldStripDataUriPrefixWhenDecodingCoverImage() {
        byte[] expected = "hello".getBytes();
        String base64 = "data:image/jpeg;base64," + Base64.getEncoder().encodeToString(expected);
        assertArrayEquals(expected, CoverDecoder.decodeCoverImage(base64));
    }

    @Test
    void shouldThrowNotFoundWhenDataUriPrefixHasNoComma() {
        ResponseStatusException ex = assertThrows(ResponseStatusException.class,
                () -> CoverDecoder.decodeCoverImage("data:image/jpeg-no-comma-here"));
        assertEquals(HttpStatus.NOT_FOUND, ex.getStatusCode());
    }

    @Test
    void shouldDecodeRawBase64CoverImage() {
        byte[] expected = "world".getBytes();
        assertArrayEquals(expected, CoverDecoder.decodeCoverImage(
                Base64.getEncoder().encodeToString(expected)));
    }

    @Test
    void shouldThrowNotFoundWhenCoverImageBase64IsInvalid() {
        assertThrows(ResponseStatusException.class,
                () -> CoverDecoder.decodeCoverImage("!!!invalid!!!"));
    }

    // ── getAlbums ────────────────────────────────────────────────────────────

    @Test
    void shouldReturnPagedAlbumResults() {
        AlbumListProjection proj = mock(AlbumListProjection.class);
        when(proj.getHash()).thenReturn("album-hash");
        when(proj.getName()).thenReturn("Album Name");
        when(proj.getSongFileHashesCsv()).thenReturn(null);
        when(albumRepository.findAllWithHashes(eq(""), any())).thenReturn(new PageImpl<>(List.of(proj)));

        AlbumPageDto result = service.getAlbums(null, 0, 20, null);

        assertEquals(1, result.getContent().size());
        assertEquals("album-hash", result.getContent().getFirst().getHash());
    }

    @Test
    void shouldKeepMappedArtistWhenSplittingHashes() {
        AlbumListProjection proj = mock(AlbumListProjection.class);
        when(proj.getHash()).thenReturn("album-hash");
        when(proj.getName()).thenReturn("Album Name");
        when(proj.getSongFileHashesCsv()).thenReturn("h1,h2");
        when(proj.getArtistHash()).thenReturn("artist-hash");
        when(proj.getArtistName()).thenReturn("Artist Name");

        when(albumRepository.findAllWithHashes(eq(""), any())).thenReturn(new PageImpl<>(List.of(proj)));

        AlbumPageDto result = service.getAlbums(null, 0, 20, null);

        assertEquals("album-hash", result.getContent().getFirst().getHash());
        assertEquals("artist-hash", result.getContent().getFirst().getArtist().getHash());
        assertEquals(List.of("h1", "h2"), result.getContent().getFirst().getSongFileHashes());
    }

    @Test
    void shouldPassBlankAlbumQueryAsEmpty() {
        when(albumRepository.findAllWithHashes(eq(""), any())).thenReturn(Page.empty());
        service.getAlbums("   ", 0, 20, null);
        verify(albumRepository).findAllWithHashes(eq(""), any());
    }

    @Test
    void shouldPassNonBlankAlbumQueryThrough() {
        when(albumRepository.findAllWithHashes(eq("rock"), any())).thenReturn(Page.empty());
        service.getAlbums("rock", 0, 20, null);
        verify(albumRepository).findAllWithHashes(eq("rock"), any());
    }

    @Test
    void shouldSortAlbumsAscendingWhenExplicitAscProvided() {
        when(sortMapper.toSort("name,asc")).thenReturn(
                org.springframework.data.domain.Sort.by(org.springframework.data.domain.Sort.Order.asc("name")));
        when(albumRepository.findAllWithHashes(any(),
                argThat(p -> p.getSort().getOrderFor("name") != null
                        && p.getSort().getOrderFor("name").isAscending())))
                .thenReturn(Page.empty());
        service.getAlbums(null, 0, 20, "name,asc");
        verify(albumRepository).findAllWithHashes(any(),
                argThat(p -> p.getSort().getOrderFor("name") != null
                        && p.getSort().getOrderFor("name").isAscending()));
    }

    @Test
    void shouldSortAlbumsDescendingWhenRequested() {
        when(sortMapper.toSort("name,desc")).thenReturn(
                org.springframework.data.domain.Sort.by(org.springframework.data.domain.Sort.Order.desc("name")));
        when(albumRepository.findAllWithHashes(any(),
                argThat(p -> p.getSort().getOrderFor("name") != null
                        && p.getSort().getOrderFor("name").isDescending())))
                .thenReturn(Page.empty());
        service.getAlbums(null, 0, 20, "name,desc");
        verify(albumRepository).findAllWithHashes(any(),
                argThat(p -> p.getSort().getOrderFor("name") != null
                        && p.getSort().getOrderFor("name").isDescending()));
    }

    @Test
    void shouldSplitCsvHashesFromProjection() {
        AlbumListProjection proj = mock(AlbumListProjection.class);
        when(proj.getSongFileHashesCsv()).thenReturn("hash1,hash2,hash3");
        when(proj.getArtistHash()).thenReturn(null);
        when(proj.getArtistName()).thenReturn(null);

        when(albumRepository.findAllWithHashes(eq(""), any())).thenReturn(new PageImpl<>(List.of(proj)));

        AlbumPageDto result = service.getAlbums(null, 0, 20, null);

        assertEquals(List.of("hash1", "hash2", "hash3"), result.getContent().getFirst().getSongFileHashes());
    }

    @Test
    void shouldReturnEmptyHashesWhenProjectionCsvIsNull() {
        AlbumListProjection proj = mock(AlbumListProjection.class);
        when(proj.getSongFileHashesCsv()).thenReturn(null);
        when(proj.getArtistHash()).thenReturn(null);
        when(proj.getArtistName()).thenReturn(null);
        when(albumRepository.findAllWithHashes(eq(""), any())).thenReturn(new PageImpl<>(List.of(proj)));

        AlbumPageDto result = service.getAlbums(null, 0, 20, null);

        assertTrue(result.getContent().getFirst().getSongFileHashes().isEmpty());
    }

    // ── getAlbumByHash ───────────────────────────────────────────────────────

    @Test
    void shouldReturnEmptyArtistsWhenAlbumHasNoArtists() {
        Album album = Album.builder().id(1L).hash("thriller-hash").name("Thriller").artists(Set.of()).build();
        when(albumRepository.findByHash("thriller-hash")).thenReturn(Optional.of(album));

        AlbumDetailDto result = service.getAlbumByHash("thriller-hash");

        assertTrue(result.getArtists().isEmpty());
    }

    @Test
    void shouldReturnAlbumDetailDto() {
        Album album = Album.builder().id(1L).hash("thriller-hash").name("Thriller").build();
        when(albumRepository.findByHash("thriller-hash")).thenReturn(Optional.of(album));

        AlbumDetailDto result = service.getAlbumByHash("thriller-hash");

        assertEquals("thriller-hash", result.getHash());
        assertEquals("Thriller", result.getName());
    }

    @Test
    void shouldThrow404WhenAlbumByHashNotFound() {
        when(albumRepository.findByHash("missing-hash")).thenReturn(Optional.empty());
        ResponseStatusException ex = assertThrows(ResponseStatusException.class,
                () -> service.getAlbumByHash("missing-hash"));
        assertEquals(HttpStatus.NOT_FOUND, ex.getStatusCode());
    }

    @Test
    void shouldMapArtistsWhenAlbumArtistsArePresent() {
        Artist artistA = Artist.builder().id(5L).hash("mj-hash").name("MJ").build();
        Artist artistB = Artist.builder().id(6L).hash("guest-hash").name("Guest").build();
        Album album = Album.builder().id(1L).hash("thriller-hash").name("Thriller").artists(Set.of(artistA, artistB)).build();
        when(albumRepository.findByHash("thriller-hash")).thenReturn(Optional.of(album));

        AlbumDetailDto result = service.getAlbumByHash("thriller-hash");

        assertEquals(2, result.getArtists().size());
        assertTrue(result.getArtists().stream().anyMatch(a -> "guest-hash".equals(a.getHash()) && "Guest".equals(a.getName())));
        assertTrue(result.getArtists().stream().anyMatch(a -> "mj-hash".equals(a.getHash()) && "MJ".equals(a.getName())));
    }

    @Test
    void shouldMapSongsWhenGettingAlbumById() {
        Song song = Song.builder().id(100L).name("Billie Jean").songType(ContentType.STREAMABLE)
                .fileHash("hash").build();
        Album album = Album.builder().id(1L).hash("thriller-hash").name("Thriller").songs(List.of(song)).build();
        when(albumRepository.findByHash("thriller-hash")).thenReturn(Optional.of(album));

        AlbumDetailDto result = service.getAlbumByHash("thriller-hash");

        assertEquals(1, result.getSongs().size());
        assertEquals("hash", result.getSongs().getFirst().getFileHash());
    }

    @Test
    void shouldReturnEmptySongsWhenAlbumSongsAreNull() {
        Album album = Album.builder().id(1L).hash("no-songs-hash").name("No Songs").songs(null).build();
        when(albumRepository.findByHash("no-songs-hash")).thenReturn(Optional.of(album));

        AlbumDetailDto result = service.getAlbumByHash("no-songs-hash");

        assertNull(result.getSongs());
    }

    // ── getAlbumCover ────────────────────────────────────────────────────────

    @Test
    void shouldReturnAlbumCoverBytes() {
        byte[] img = "imgdata".getBytes();
        Album album = Album.builder().id(1L).hash("album-hash")
                .coverImage(Base64.getEncoder().encodeToString(img)).build();
        when(albumRepository.findByHash("album-hash")).thenReturn(Optional.of(album));

        assertArrayEquals(img, service.getAlbumCover("album-hash"));
    }

    @Test
    void shouldThrow404WhenAlbumCoverAlbumNotFound() {
        when(albumRepository.findByHash("missing-hash")).thenReturn(Optional.empty());
        assertThrows(ResponseStatusException.class, () -> service.getAlbumCover("missing-hash"));
    }

    @Test
    void shouldThrow404WhenAlbumCoverIsNull() {
        Album album = Album.builder().id(1L).hash("null-cover-hash").coverImage(null).build();
        when(albumRepository.findByHash("null-cover-hash")).thenReturn(Optional.of(album));
        ResponseStatusException ex = assertThrows(ResponseStatusException.class,
                () -> service.getAlbumCover("null-cover-hash"));
        assertEquals(HttpStatus.NOT_FOUND, ex.getStatusCode());
    }
}
