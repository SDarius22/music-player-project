package com.example.musicplayerbackend.service;

import com.example.musicplayerbackend.data.AlbumRepository;
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
import java.util.LinkedHashSet;
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
        Artist artist = Artist.builder().id(1L).hash("artist-hash").name("Artist Name").build();
        Song song = Song.builder().name("Track").fileHash("song-hash").songType(ContentType.STREAMABLE).artist(artist).build();
        Album album = Album.builder()
                .hash("album-hash")
                .name("Album Name")
                .artists(Set.of(artist))
                .songs(List.of(song))
                .build();
        when(albumRepository.findAllByNameContainingIgnoreCase(eq(""), any())).thenReturn(new PageImpl<>(List.of(album)));

        AlbumPageDto result = service.getAlbums(null, 0, 20, null);

        assertEquals(1, result.getContent().size());
        assertEquals("album-hash", result.getContent().getFirst().getHash());
    }

    @Test
    void shouldKeepMappedArtistWhenSplittingHashes() {
        Artist artist = Artist.builder().id(1L).hash("artist-hash").name("Artist Name").build();
        Song song1 = Song.builder().name("Track 1").fileHash("h1").songType(ContentType.STREAMABLE).artist(artist).build();
        Song song2 = Song.builder().name("Track 2").fileHash("h2").songType(ContentType.STREAMABLE).artist(artist).build();
        Album album = Album.builder()
                .hash("album-hash")
                .name("Album Name")
                .artists(Set.of(artist))
                .songs(List.of(song1, song2))
                .build();

        when(albumRepository.findAllByNameContainingIgnoreCase(eq(""), any())).thenReturn(new PageImpl<>(List.of(album)));

        AlbumPageDto result = service.getAlbums(null, 0, 20, null);

        assertEquals("album-hash", result.getContent().getFirst().getHash());
        assertEquals("artist-hash", result.getContent().getFirst().getArtist().getHash());
        assertEquals(List.of("h1", "h2"), result.getContent().getFirst().getSongFileHashes());
    }

    @Test
    void shouldPassBlankAlbumQueryAsEmpty() {
        when(albumRepository.findAllByNameContainingIgnoreCase(eq(""), any())).thenReturn(Page.empty());
        service.getAlbums("   ", 0, 20, null);
        verify(albumRepository).findAllByNameContainingIgnoreCase(eq(""), any());
    }

    @Test
    void shouldPassNonBlankAlbumQueryThrough() {
        when(albumRepository.findAllByNameContainingIgnoreCase(eq("rock"), any())).thenReturn(Page.empty());
        service.getAlbums("rock", 0, 20, null);
        verify(albumRepository).findAllByNameContainingIgnoreCase(eq("rock"), any());
    }

    @Test
    void shouldSortAlbumsAscendingWhenExplicitAscProvided() {
        when(sortMapper.toSort("name,asc")).thenReturn(
                org.springframework.data.domain.Sort.by(org.springframework.data.domain.Sort.Order.asc("name")));
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
    void shouldSortAlbumsDescendingWhenRequested() {
        when(sortMapper.toSort("name,desc")).thenReturn(
                org.springframework.data.domain.Sort.by(org.springframework.data.domain.Sort.Order.desc("name")));
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
    void shouldSplitSongHashesFromAlbumSongs() {
        Artist artist = Artist.builder().id(1L).hash("artist-hash").name("Artist Name").build();
        Song song1 = Song.builder().name("Track 1").fileHash("hash1").songType(ContentType.STREAMABLE).artist(artist).build();
        Song song2 = Song.builder().name("Track 2").fileHash("hash2").songType(ContentType.STREAMABLE).artist(artist).build();
        Song song3 = Song.builder().name("Track 3").fileHash("hash3").songType(ContentType.STREAMABLE).artist(artist).build();
        Album album = Album.builder().hash("album-hash").name("Album Name").artists(Set.of(artist)).songs(List.of(song1, song2, song3)).build();

        when(albumRepository.findAllByNameContainingIgnoreCase(eq(""), any())).thenReturn(new PageImpl<>(List.of(album)));

        AlbumPageDto result = service.getAlbums(null, 0, 20, null);

        assertEquals(List.of("hash1", "hash2", "hash3"), result.getContent().getFirst().getSongFileHashes());
    }

    @Test
    void shouldReturnEmptyHashesWhenAlbumSongsAreEmpty() {
        Artist artist = Artist.builder().id(1L).hash("artist-hash").name("Artist Name").build();
        Album album = Album.builder().hash("album-hash").name("Album Name").artists(Set.of(artist)).songs(List.of()).build();
        when(albumRepository.findAllByNameContainingIgnoreCase(eq(""), any())).thenReturn(new PageImpl<>(List.of(album)));

        AlbumPageDto result = service.getAlbums(null, 0, 20, null);

        assertTrue(result.getContent().getFirst().getSongFileHashes().isEmpty());
    }

    @Test
    void shouldPickArtistWithMostSongsAsMainArtist() {
        Artist mainArtist = Artist.builder().id(1L).hash("main-hash").name("Main Artist").build();
        Artist featuredArtist = Artist.builder().id(2L).hash("featured-hash").name("Featured Artist").build();
        Album album = Album.builder().hash("album-hash").name("Album Name").artists(Set.of(mainArtist, featuredArtist)).build();

        Song mainSong1 = Song.builder().id(10L).name("Track 1").fileHash("h1").songType(ContentType.STREAMABLE).artist(mainArtist).album(album).build();
        Song mainSong2 = Song.builder().id(11L).name("Track 2").fileHash("h2").songType(ContentType.STREAMABLE).artist(mainArtist).album(album).build();
        Song featuredSong = Song.builder().id(12L).name("Track 3").fileHash("h3").songType(ContentType.STREAMABLE).artist(featuredArtist).album(album).build();
        album.setSongs(List.of(mainSong1, mainSong2, featuredSong));

        when(albumRepository.findAllByNameContainingIgnoreCase(eq(""), any())).thenReturn(new PageImpl<>(List.of(album)));

        AlbumPageDto result = service.getAlbums(null, 0, 20, null);

        assertEquals("main-hash", result.getContent().getFirst().getArtist().getHash());
    }

    @Test
    void shouldFallbackToFirstArtistWhenNoSongsMatchAnyArtist() {
        Artist firstArtist = Artist.builder().id(1L).hash("first-hash").name("First Artist").build();
        Artist secondArtist = Artist.builder().id(2L).hash("second-hash").name("Second Artist").build();
        var artists = new LinkedHashSet<Artist>();
        artists.add(firstArtist);
        artists.add(secondArtist);

        Album album = Album.builder()
                .hash("album-hash")
                .name("Album Name")
                .artists(artists)
                .songs(List.of())
                .build();

        when(albumRepository.findAllByNameContainingIgnoreCase(eq(""), any())).thenReturn(new PageImpl<>(List.of(album)));

        AlbumPageDto result = service.getAlbums(null, 0, 20, null);

        assertEquals("first-hash", result.getContent().getFirst().getArtist().getHash());
    }

    // ── getAlbumByHash ───────────────────────────────────────────────────────

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
