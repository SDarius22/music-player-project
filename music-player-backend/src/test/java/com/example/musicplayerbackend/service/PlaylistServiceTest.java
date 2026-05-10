package com.example.musicplayerbackend.service;

import com.example.musicplayerbackend.data.PlaylistRepository;
import com.example.musicplayerbackend.data.PlaylistSongRepository;
import com.example.musicplayerbackend.data.SongRepository;
import com.example.musicplayerbackend.data.projection.PlaylistListProjection;
import com.example.musicplayerbackend.domain.*;
import com.example.musicplayerbackend.mapper.PlaylistMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Captor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.PageImpl;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

import java.time.Instant;
import java.util.Base64;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class PlaylistServiceTest {

    @Mock
    PlaylistRepository playlistRepository;
    @Mock
    PlaylistSongRepository playlistSongRepository;
    @Mock
    SongRepository songRepository;
    @Mock
    PlaylistMapper playlistMapper;
    @Mock
    SongEnrichmentService songEnrichmentService;

    @Captor
    ArgumentCaptor<List<PlaylistSong>> playlistSongsCaptor;

    PlaylistService service;
    User owner;

    @BeforeEach
    void setUp() {
        service = new PlaylistService(playlistRepository, playlistSongRepository, songRepository, playlistMapper, songEnrichmentService);
        owner = User.builder().id(1L).email("u@test.com").role(Role.USER)
                .provider(AuthProvider.LOCAL).build();

        lenient().when(songEnrichmentService.enrich(anyList(), any())).thenAnswer(inv -> {
            List<Song> songs = inv.getArgument(0);
            return songs.stream().map(s -> {
                SongDto dto = new SongDto();
                dto.setFileHash(s.getFileHash());
                dto.setName(s.getName());
                return dto;
            }).toList();
        });
    }

    // ── getPlaylists ─────────────────────────────────────────────────────────

    @Test
    void shouldReturnPagedPlaylistDtos() {
        PlaylistListProjection proj = mock(PlaylistListProjection.class);
        PlaylistDto dto = new PlaylistDto();
        dto.setName("My Mix");
        when(playlistRepository.findAllWithHashes(eq(1L), any(), any(), any())).thenReturn(new PageImpl<>(List.of(proj)));
        when(playlistMapper.toDto(proj)).thenReturn(dto);

        PlaylistPageDto result = service.getPlaylists(1L, null, null, null, null, 0, 20);

        assertEquals(1, result.getContent().size());
        assertEquals("My Mix", result.getContent().getFirst().getName());
    }

    @Test
    void shouldReturnEmptyHashesWhenProjectionCsvIsNull() {
        PlaylistListProjection proj = mock(PlaylistListProjection.class);
        PlaylistDto dto = new PlaylistDto();
        dto.setSongFileHashes(List.of());
        when(playlistRepository.findAllWithHashes(eq(1L), any(), any(), any())).thenReturn(new PageImpl<>(List.of(proj)));
        when(playlistMapper.toDto(proj)).thenReturn(dto);

        PlaylistPageDto result = service.getPlaylists(1L, null, null, null, null, 0, 20);

        assertTrue(result.getContent().getFirst().getSongFileHashes().isEmpty());
    }

    @Test
    void shouldSplitCsvHashesFromPlaylistProjection() {
        PlaylistListProjection proj = mock(PlaylistListProjection.class);
        PlaylistDto dto = new PlaylistDto();
        dto.setSongFileHashes(List.of("h1", "h2", "h3"));
        when(playlistRepository.findAllWithHashes(eq(1L), any(), any(), any())).thenReturn(new PageImpl<>(List.of(proj)));
        when(playlistMapper.toDto(proj)).thenReturn(dto);

        PlaylistPageDto result = service.getPlaylists(1L, null, null, null, null, 0, 20);

        assertEquals(List.of("h1", "h2", "h3"), result.getContent().getFirst().getSongFileHashes());
    }

    // ── createPlaylist ───────────────────────────────────────────────────────

    @Test
    void shouldPersistPlaylistSongsInRequestedOrderWhenCreatingPlaylist() {
        CreatePlaylistDto req = new CreatePlaylistDto();
        req.setName("New Playlist");
        req.setPlaylistSongs(List.of(songInput("h2", 1), songInput("h1", 2)));

        Song song1 = Song.builder().id(10L).name("S1").songType(ContentType.STREAMABLE).fileHash("h1").build();
        Song song2 = Song.builder().id(20L).name("S2").songType(ContentType.STREAMABLE).fileHash("h2").build();

        Playlist saved = Playlist.builder().id(99L).user(owner).name("New Playlist")
                .createdAt(Instant.now()).updatedAt(Instant.now()).build();

        PlaylistSong ps0 = PlaylistSong.builder().id(new PlaylistSongId(99L, 0)).playlist(saved).song(song2).build();
        PlaylistSong ps1 = PlaylistSong.builder().id(new PlaylistSongId(99L, 1)).playlist(saved).song(song1).build();

        when(playlistRepository.save(any())).thenReturn(saved);
        when(songRepository.findAllByFileHashIn(List.of("h2", "h1"))).thenReturn(List.of(song1, song2));
        when(playlistSongRepository.findByPlaylist_IdOrderById_PositionAsc(99L)).thenReturn(List.of(ps0, ps1));

        PlaylistExpandedDto result = service.createPlaylist(owner, req);

        verify(playlistSongRepository).saveAll(playlistSongsCaptor.capture());
        List<PlaylistSong> persisted = playlistSongsCaptor.getValue();
        assertEquals(2, persisted.size());
        assertEquals(1, persisted.get(0).getId().getPosition());
        assertEquals(20L, persisted.get(0).getSong().getId());
        assertEquals(2, persisted.get(1).getId().getPosition());
        assertEquals(10L, persisted.get(1).getSong().getId());

        assertEquals(List.of("h2", "h1"), result.getSongFileHashes());
    }

    @Test
    void shouldThrow400WhenCreatingPlaylistWithNullSongs() {
        CreatePlaylistDto req = new CreatePlaylistDto();
        req.setName("Empty Playlist");
        req.setPlaylistSongs(null);

        ResponseStatusException ex = assertThrows(ResponseStatusException.class,
                () -> service.createPlaylist(owner, req));

        assertEquals(HttpStatus.BAD_REQUEST, ex.getStatusCode());
        verify(playlistRepository, never()).save(any());
        verify(playlistSongRepository, never()).deleteByPlaylist_Id(anyLong());
        verify(playlistSongRepository, never()).saveAll(anyList());
    }

    @Test
    void shouldThrow400WhenCreatingPlaylistWithEmptySongs() {
        CreatePlaylistDto req = new CreatePlaylistDto();
        req.setName("Empty Playlist");
        req.setPlaylistSongs(List.of());

        ResponseStatusException ex = assertThrows(ResponseStatusException.class,
                () -> service.createPlaylist(owner, req));

        assertEquals(HttpStatus.BAD_REQUEST, ex.getStatusCode());
        verify(playlistRepository, never()).save(any());
        verify(playlistSongRepository, never()).deleteByPlaylist_Id(anyLong());
        verify(playlistSongRepository, never()).saveAll(anyList());
    }

    @Test
    void shouldReturnSongsInPositionOrderWhenGettingPlaylistDetail() {
        Playlist playlist = Playlist.builder().id(5L).user(owner).name("Ordered")
                .createdAt(Instant.now()).updatedAt(Instant.now()).build();
        Song song1 = Song.builder().id(11L).fileHash("h1").songType(ContentType.STREAMABLE).name("S1").build();
        Song song2 = Song.builder().id(22L).fileHash("h2").songType(ContentType.STREAMABLE).name("S2").build();

        PlaylistSong ps0 = PlaylistSong.builder().id(new PlaylistSongId(5L, 0)).playlist(playlist).song(song2).build();
        PlaylistSong ps1 = PlaylistSong.builder().id(new PlaylistSongId(5L, 1)).playlist(playlist).song(song1).build();

        when(playlistRepository.findById(5L)).thenReturn(Optional.of(playlist));
        when(playlistSongRepository.findByPlaylist_IdOrderById_PositionAsc(5L)).thenReturn(List.of(ps0, ps1));

        PlaylistExpandedDto result = service.getPlaylistById(5L, 1L);

        assertEquals(List.of("h2", "h1"), result.getSongFileHashes());
    }

    @Test
    void shouldNotReplaceSongsWhenUpdateSongHashesIsNull() {
        Playlist playlist = Playlist.builder().id(1L).user(owner).name("Mix")
                .createdAt(Instant.now()).updatedAt(Instant.now()).build();
        when(playlistRepository.findById(1L)).thenReturn(Optional.of(playlist));
        when(playlistRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
        when(playlistSongRepository.findByPlaylist_IdOrderById_PositionAsc(1L)).thenReturn(List.of());

        UpdatePlaylistDto req = new UpdatePlaylistDto();
        req.setPlaylistSongs(null);

        service.updatePlaylist(1L, 1L, req);

        verify(playlistSongRepository, never()).deleteByPlaylist_Id(1L);
        verify(playlistSongRepository, never()).saveAll(anyList());
    }

    @Test
    void shouldReplaceSongsWhenUpdateSongHashesProvided() {
        Playlist playlist = Playlist.builder().id(1L).user(owner).name("Mix")
                .createdAt(Instant.now()).updatedAt(Instant.now()).build();
        Song song = Song.builder().id(5L).name("New Song").songType(ContentType.STREAMABLE).fileHash("h").build();
        PlaylistSong relation = PlaylistSong.builder()
                .id(new PlaylistSongId(1L, 0))
                .playlist(playlist)
                .song(song)
                .build();
        when(playlistRepository.findById(1L)).thenReturn(Optional.of(playlist));
        when(playlistRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
        when(songRepository.findAllByFileHashIn(List.of("h"))).thenReturn(List.of(song));
        when(playlistSongRepository.findByPlaylist_IdOrderById_PositionAsc(1L)).thenReturn(List.of(relation));

        UpdatePlaylistDto req = new UpdatePlaylistDto();
        req.setPlaylistSongs(List.of(songInput("h", 0)));

        PlaylistExpandedDto result = service.updatePlaylist(1L, 1L, req);

        verify(playlistSongRepository).deleteByPlaylist_Id(1L);
        verify(playlistSongRepository).saveAll(anyList());
        assertEquals(1, result.getSongFileHashes().size());
    }

    @Test
    void shouldThrow400WhenUpdateContainsDuplicatePositions() {
        Playlist playlist = Playlist.builder().id(1L).user(owner).name("Mix")
                .createdAt(Instant.now()).updatedAt(Instant.now()).build();
        when(playlistRepository.findById(1L)).thenReturn(Optional.of(playlist));

        UpdatePlaylistDto req = new UpdatePlaylistDto();
        req.setPlaylistSongs(List.of(songInput("h1", 0), songInput("h2", 0)));

        ResponseStatusException ex = assertThrows(ResponseStatusException.class,
                () -> service.updatePlaylist(1L, 1L, req));
        assertEquals(HttpStatus.BAD_REQUEST, ex.getStatusCode());
    }

    // ── getPlaylistById ──────────────────────────────────────────────────────

    @Test
    void shouldReturnPlaylistDetailDto() {
        Playlist p = Playlist.builder().id(1L).user(owner).name("Chill")
                .createdAt(Instant.now()).updatedAt(Instant.now()).build();
        when(playlistRepository.findById(1L)).thenReturn(Optional.of(p));
        when(playlistSongRepository.findByPlaylist_IdOrderById_PositionAsc(1L)).thenReturn(List.of());

        PlaylistExpandedDto result = service.getPlaylistById(1L, 1L);

        assertEquals(1L, result.getId());
        assertEquals("Chill", result.getName());
    }

    @Test
    void shouldThrow404WhenPlaylistByIdNotFound() {
        when(playlistRepository.findById(99L)).thenReturn(Optional.empty());
        ResponseStatusException ex = assertThrows(ResponseStatusException.class,
                () -> service.getPlaylistById(99L, 1L));
        assertEquals(HttpStatus.NOT_FOUND, ex.getStatusCode());
    }

    @Test
    void shouldThrow403WhenPlaylistOwnedByDifferentUser() {
        Playlist playlist = Playlist.builder().id(1L).user(owner).name("Mine")
                .createdAt(Instant.now()).updatedAt(Instant.now()).build();
        when(playlistRepository.findById(1L)).thenReturn(Optional.of(playlist));

        ResponseStatusException ex = assertThrows(ResponseStatusException.class,
                () -> service.getPlaylistById(1L, 999L));
        assertEquals(HttpStatus.FORBIDDEN, ex.getStatusCode());
    }

    // ── deletePlaylist ───────────────────────────────────────────────────────

    @Test
    void shouldDeletePlaylist() {
        Playlist playlist = Playlist.builder().id(1L).user(owner).name("To Delete")
                .createdAt(Instant.now()).updatedAt(Instant.now()).build();
        when(playlistRepository.findById(1L)).thenReturn(Optional.of(playlist));

        service.deletePlaylist(1L, 1L);

        verify(playlistRepository).delete(playlist);
    }

    // ── getPlaylistCover ─────────────────────────────────────────────────────

    @Test
    void shouldReturnPlaylistCoverBytes() {
        byte[] img = "img".getBytes();
        Playlist playlist = Playlist.builder().id(1L).user(owner).name("P")
                .coverImage(Base64.getEncoder().encodeToString(img))
                .createdAt(Instant.now()).updatedAt(Instant.now()).build();
        when(playlistRepository.findById(1L)).thenReturn(Optional.of(playlist));

        assertArrayEquals(img, service.getPlaylistCover(1L, 1L));
    }

    @Test
    void shouldFallbackToFirstSongAlbumCoverWhenPlaylistHasNoCover() {
        byte[] img = "album-img".getBytes();
        Album album = Album.builder().id(3L).coverImage(Base64.getEncoder().encodeToString(img)).name("A").hash("h").build();
        Song song = Song.builder().id(2L).name("S").songType(ContentType.STREAMABLE).fileHash("f").album(album).build();
        Playlist playlist = Playlist.builder().id(1L).user(owner).name("P")
                .coverImage(null)
                .createdAt(Instant.now()).updatedAt(Instant.now()).build();
        PlaylistSong relation = PlaylistSong.builder()
                .id(new PlaylistSongId(1L, 0))
                .playlist(playlist)
                .song(song)
                .build();

        when(playlistRepository.findById(1L)).thenReturn(Optional.of(playlist));
        when(playlistSongRepository.findByPlaylist_IdOrderById_PositionAsc(1L)).thenReturn(List.of(relation));

        assertArrayEquals(img, service.getPlaylistCover(1L, 1L));
    }

    private PlaylistSongPositionDto songInput(String fileHash, int position) {
        PlaylistSongPositionDto dto = new PlaylistSongPositionDto();
        dto.setSongFileHash(fileHash);
        dto.setPosition(position);
        return dto;
    }

    @Test
    void shouldThrowNotFoundWhenPlaylistHasNoCover() {
        Playlist p = Playlist.builder().id(1L).user(owner).name("P")
                .coverImage(null)
                .createdAt(Instant.now()).updatedAt(Instant.now()).build();
        when(playlistRepository.findById(1L)).thenReturn(Optional.of(p));
        when(playlistSongRepository.findByPlaylist_IdOrderById_PositionAsc(1L)).thenReturn(List.of());
        assertThrows(ResponseStatusException.class, () -> service.getPlaylistCover(1L, 1L));
    }

    @Test
    void shouldThrow403WhenGettingPlaylistCoverOwnedByDifferentUser() {
        Playlist p = Playlist.builder().id(1L).user(owner).name("P")
                .coverImage("some-cover")
                .createdAt(Instant.now()).updatedAt(Instant.now()).build();
        when(playlistRepository.findById(1L)).thenReturn(Optional.of(p));
        ResponseStatusException ex = assertThrows(ResponseStatusException.class,
                () -> service.getPlaylistCover(1L, 999L));
        assertEquals(HttpStatus.FORBIDDEN, ex.getStatusCode());
    }
}
