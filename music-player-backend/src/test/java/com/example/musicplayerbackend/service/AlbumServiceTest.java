package com.example.musicplayerbackend.service;

import com.example.musicplayerbackend.data.AlbumRepository;
import com.example.musicplayerbackend.data.projection.AlbumListProjection;
import com.example.musicplayerbackend.domain.*;
import com.example.musicplayerbackend.helpers.CoverDecoder;
import com.example.musicplayerbackend.mapper.AlbumMapper;
import com.example.musicplayerbackend.mapper.SongMapper;
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
class AlbumServiceTest {

    @Mock AlbumRepository albumRepository;
    @Mock AlbumMapper albumMapper;
    @Mock SongMapper songMapper;
    @Mock SortMapper sortMapper;

    AlbumService service;

    @BeforeEach
    void setUp() {
        service = new AlbumService(albumRepository, albumMapper, songMapper, sortMapper);
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
        when(proj.getSongFileHashesCsv()).thenReturn(null);
        AlbumListDto listDto = new AlbumListDto();
        listDto.setId(1L);
        when(albumRepository.findAllWithHashes(eq(""), any())).thenReturn(new PageImpl<>(List.of(proj)));
        when(albumMapper.toListDto(proj)).thenReturn(listDto);

        AlbumPageDto result = service.getAlbums(null, 0, 20, null);

        assertEquals(1, result.getContent().size());
        assertEquals(1L, result.getContent().getFirst().getId());
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
        AlbumListDto listDto = new AlbumListDto();
        when(albumRepository.findAllWithHashes(eq(""), any())).thenReturn(new PageImpl<>(List.of(proj)));
        when(albumMapper.toListDto(proj)).thenReturn(listDto);

        AlbumPageDto result = service.getAlbums(null, 0, 20, null);

        assertEquals(List.of("hash1", "hash2", "hash3"), result.getContent().getFirst().getSongFileHashes());
    }

    @Test
    void shouldReturnEmptyHashesWhenProjectionCsvIsNull() {
        AlbumListProjection proj = mock(AlbumListProjection.class);
        when(proj.getSongFileHashesCsv()).thenReturn(null);
        AlbumListDto listDto = new AlbumListDto();
        when(albumRepository.findAllWithHashes(eq(""), any())).thenReturn(new PageImpl<>(List.of(proj)));
        when(albumMapper.toListDto(proj)).thenReturn(listDto);

        AlbumPageDto result = service.getAlbums(null, 0, 20, null);

        assertTrue(result.getContent().getFirst().getSongFileHashes().isEmpty());
    }

    // ── getAlbumById ─────────────────────────────────────────────────────────

    @Test
    void shouldReturnNullArtistDtoWhenAlbumArtistIsNull() {
        Album album = Album.builder().id(1L).name("Thriller").artist(null).build();
        when(albumRepository.findById(1L)).thenReturn(Optional.of(album));

        AlbumDetailDto result = service.getAlbumById(1L);

        assertNull(result.getArtist());
    }

    @Test
    void shouldReturnAlbumDetailDto() {
        Album album = Album.builder().id(1L).name("Thriller").build();
        when(albumRepository.findById(1L)).thenReturn(Optional.of(album));

        AlbumDetailDto result = service.getAlbumById(1L);

        assertEquals(1L, result.getId());
        assertEquals("Thriller", result.getName());
    }

    @Test
    void shouldThrow404WhenAlbumByIdNotFound() {
        when(albumRepository.findById(99L)).thenReturn(Optional.empty());
        ResponseStatusException ex = assertThrows(ResponseStatusException.class,
                () -> service.getAlbumById(99L));
        assertEquals(HttpStatus.NOT_FOUND, ex.getStatusCode());
    }

    @Test
    void shouldMapArtistWhenAlbumArtistIsPresent() {
        Artist artist = Artist.builder().id(5L).name("MJ").build();
        Album album = Album.builder().id(1L).name("Thriller").artist(artist).build();
        when(albumRepository.findById(1L)).thenReturn(Optional.of(album));

        AlbumDetailDto result = service.getAlbumById(1L);

        assertNotNull(result.getArtist());
        assertEquals(5L, result.getArtist().getId());
        assertEquals("MJ", result.getArtist().getName());
    }

    @Test
    void shouldMapSongsWhenGettingAlbumById() {
        Song song = Song.builder().id(100L).name("Billie Jean").songType(ContentType.STREAMABLE)
                .fileHash("hash").build();
        Album album = Album.builder().id(1L).name("Thriller").songs(List.of(song)).build();
        SongDto songDto = new SongDto();
        songDto.setFileHash("hash");
        when(albumRepository.findById(1L)).thenReturn(Optional.of(album));
        when(songMapper.toDto(song)).thenReturn(songDto);

        AlbumDetailDto result = service.getAlbumById(1L);

        assertEquals(1, result.getSongs().size());
        assertEquals("hash", result.getSongs().getFirst().getFileHash());
    }

    @Test
    void shouldReturnEmptySongsWhenAlbumSongsAreNull() {
        Album album = Album.builder().id(1L).name("No Songs").songs(null).build();
        when(albumRepository.findById(1L)).thenReturn(Optional.of(album));

        AlbumDetailDto result = service.getAlbumById(1L);

        assertTrue(result.getSongs().isEmpty());
    }

    // ── getAlbumCover ────────────────────────────────────────────────────────

    @Test
    void shouldReturnAlbumCoverBytes() {
        byte[] img = "imgdata".getBytes();
        Album album = Album.builder().id(1L)
                .coverImage(Base64.getEncoder().encodeToString(img)).build();
        when(albumRepository.findById(1L)).thenReturn(Optional.of(album));

        assertArrayEquals(img, service.getAlbumCover(1L));
    }

    @Test
    void shouldThrow404WhenAlbumCoverAlbumNotFound() {
        when(albumRepository.findById(1L)).thenReturn(Optional.empty());
        assertThrows(ResponseStatusException.class, () -> service.getAlbumCover(1L));
    }

    @Test
    void shouldThrow404WhenAlbumCoverIsNull() {
        Album album = Album.builder().id(1L).coverImage(null).build();
        when(albumRepository.findById(1L)).thenReturn(Optional.of(album));
        ResponseStatusException ex = assertThrows(ResponseStatusException.class,
                () -> service.getAlbumCover(1L));
        assertEquals(HttpStatus.NOT_FOUND, ex.getStatusCode());
    }
}
