package com.example.musicplayerbackend.service;

import com.example.musicplayerbackend.data.AlbumRepository;
import com.example.musicplayerbackend.domain.*;
import com.example.musicplayerbackend.mapper.AlbumMapper;
import com.example.musicplayerbackend.mapper.SongMapper;
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
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AlbumServiceTest {

    @Mock
    AlbumRepository albumRepository;
    @Mock
    AlbumMapper albumMapper;
    @Mock
    SongMapper songMapper;

    AlbumService service;

    @BeforeEach
    void setUp() {
        service = new AlbumService(albumRepository, albumMapper, songMapper);
    }

    // ── decodeCoverImage ─────────────────────────────────────────────────────

    @Test
    void shouldThrowNotFoundWhenDecodeCoverImageIsNull() {
        ResponseStatusException ex = assertThrows(ResponseStatusException.class,
                () -> AlbumService.decodeCoverImage(null));
        assertEquals(HttpStatus.NOT_FOUND, ex.getStatusCode());
    }

    @Test
    void shouldThrowNotFoundWhenDecodeCoverImageIsBlank() {
        assertThrows(ResponseStatusException.class, () -> AlbumService.decodeCoverImage("   "));
    }

    @Test
    void shouldStripDataUriPrefixWhenDecodingCoverImage() {
        byte[] expected = "hello".getBytes();
        String base64 = "data:image/jpeg;base64," + Base64.getEncoder().encodeToString(expected);
        assertArrayEquals(expected, AlbumService.decodeCoverImage(base64));
    }

    @Test
    void shouldThrowNotFoundWhenDataUriPrefixHasNoComma() {
        // "data:..." without a comma → commaIdx = -1 → condition false → full string passed to Base64
        // colon is not valid base64 → IllegalArgumentException → 404
        ResponseStatusException ex = assertThrows(ResponseStatusException.class,
                () -> AlbumService.decodeCoverImage("data:image/jpeg-no-comma-here"));
        assertEquals(HttpStatus.NOT_FOUND, ex.getStatusCode());
    }

    @Test
    void shouldDecodeRawBase64CoverImage() {
        byte[] expected = "world".getBytes();
        assertArrayEquals(expected, AlbumService.decodeCoverImage(
                Base64.getEncoder().encodeToString(expected)));
    }

    @Test
    void shouldThrowNotFoundWhenCoverImageBase64IsInvalid() {
        assertThrows(ResponseStatusException.class,
                () -> AlbumService.decodeCoverImage("!!!invalid!!!"));
    }

    @Test
    void shouldReturnPagedAlbumResults() {
        Album album = Album.builder().id(1L).name("Jazz").build();
        AlbumDto dto = new AlbumDto();
        dto.setId(1L);
        when(albumRepository.findAllByNameContainingIgnoreCase(eq(""), any()))
                .thenReturn(new PageImpl<>(List.of(album)));
        when(albumMapper.toDto(album)).thenReturn(dto);

        AlbumPageDto result = service.getAlbums(null, 0, 20, null);

        assertEquals(1, result.getContent().size());
        assertEquals(1L, result.getContent().getFirst().getId());
    }

    @Test
    void shouldPassBlankAlbumQueryAsEmpty() {
        when(albumRepository.findAllByNameContainingIgnoreCase(eq(""), any()))
                .thenReturn(Page.empty());
        service.getAlbums("   ", 0, 20, null);
        verify(albumRepository).findAllByNameContainingIgnoreCase(eq(""), any());
    }

    @Test
    void shouldPassNonBlankAlbumQueryThrough() {
        when(albumRepository.findAllByNameContainingIgnoreCase(eq("rock"), any()))
                .thenReturn(Page.empty());
        service.getAlbums("rock", 0, 20, null);
        verify(albumRepository).findAllByNameContainingIgnoreCase(eq("rock"), any());
    }

    @Test
    void shouldSortAlbumsAscendingWhenExplicitAscProvided() {
        when(albumRepository.findAllByNameContainingIgnoreCase(any(),
                argThat(p -> p.getSort().getOrderFor("name") != null
                        && p.getSort().getOrderFor("name").isAscending())))
                .thenReturn(Page.empty());
        service.getAlbums(null, 0, 20, "name,asc");
        verify(albumRepository).findAllByNameContainingIgnoreCase(any(),
                argThat(p -> p.getSort().getOrderFor("name") != null
                        && p.getSort().getOrderFor("name").isAscending()));
    }

    @Test
    void shouldSortAlbumsAscendingWhenSortHasNoComma() {
        // parts.length == 1 → dir = "asc" (default)
        when(albumRepository.findAllByNameContainingIgnoreCase(any(),
                argThat(p -> p.getSort().getOrderFor("name") != null
                        && p.getSort().getOrderFor("name").isAscending())))
                .thenReturn(Page.empty());
        service.getAlbums(null, 0, 20, "name");
        verify(albumRepository).findAllByNameContainingIgnoreCase(any(),
                argThat(p -> p.getSort().getOrderFor("name") != null
                        && p.getSort().getOrderFor("name").isAscending()));
    }

    @Test
    void shouldSortAlbumsDescendingWhenRequested() {
        when(albumRepository.findAllByNameContainingIgnoreCase(any(),
                argThat(p -> p.getSort().getOrderFor("name") != null
                        && p.getSort().getOrderFor("name").isDescending())))
                .thenReturn(Page.empty());
        service.getAlbums(null, 0, 20, "name,desc");
        verify(albumRepository).findAllByNameContainingIgnoreCase(any(),
                argThat(p -> p.getSort().getOrderFor("name") != null
                        && p.getSort().getOrderFor("name").isDescending()));
    }

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
