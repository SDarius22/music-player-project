package com.example.musicplayerbackend.service;

import com.example.musicplayerbackend.data.PlaylistRepository;
import com.example.musicplayerbackend.data.SongRepository;
import com.example.musicplayerbackend.domain.*;
import com.example.musicplayerbackend.mapper.SongMapper;
import com.fasterxml.jackson.databind.ObjectMapper;
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
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class PlaylistServiceTest {

    @Mock
    PlaylistRepository playlistRepository;
    @Mock
    SongRepository songRepository;
    @Mock
    SongMapper songMapper;

    @Captor
    ArgumentCaptor<Playlist> playlistCaptor;

    PlaylistService service;
    User owner;

    @BeforeEach
    void setUp() {
        service = new PlaylistService(playlistRepository, songRepository, songMapper, new ObjectMapper());
        owner = User.builder().id(1L).email("u@test.com").role(Role.USER)
                .provider(AuthProvider.LOCAL).build();
    }

    @Test
    void shouldReturnPagedPlaylistDtos() {
        Playlist p = Playlist.builder().id(1L).user(owner).name("My Mix")
                .songIdsJson("[]").createdAt(Instant.now()).updatedAt(Instant.now()).build();
        when(playlistRepository.findAllByUserId(eq(1L), any())).thenReturn(new PageImpl<>(List.of(p)));

        PlaylistPageDto result = service.getPlaylists(1L, 0, 20);

        assertEquals(1, result.getContent().size());
        assertEquals("My Mix", result.getContent().getFirst().getName());
    }

    @Test
    void shouldSaveAndReturnPlaylistDetailDto() {
        CreatePlaylistDto req = new CreatePlaylistDto();
        req.setName("New Playlist");
        req.setSongIds(List.of(10L, 20L));

        Song song1 = Song.builder().id(10L).name("S1").songType(ContentType.STREAMABLE).fileHash("h1").build();
        Song song2 = Song.builder().id(20L).name("S2").songType(ContentType.STREAMABLE).fileHash("h2").build();
        SongDto dto1 = new SongDto();
        dto1.setId(10L);
        SongDto dto2 = new SongDto();
        dto2.setId(20L);

        when(playlistRepository.save(any())).thenAnswer(inv -> {
            Playlist pl = inv.getArgument(0);
            pl = Playlist.builder().id(99L).user(pl.getUser()).name(pl.getName())
                    .songIdsJson(pl.getSongIdsJson()).createdAt(Instant.now()).updatedAt(Instant.now()).build();
            return pl;
        });
        when(songRepository.findAllById(List.of(10L, 20L))).thenReturn(List.of(song1, song2));
        when(songMapper.toDto(song1)).thenReturn(dto1);
        when(songMapper.toDto(song2)).thenReturn(dto2);

        PlaylistDetailDto result = service.createPlaylist(owner, req);

        assertEquals(99L, result.getId());
        assertEquals("New Playlist", result.getName());
        assertEquals(2, result.getSongs().size());
    }

    @Test
    void shouldHandleNullSongIdsWhenCreatingPlaylist() {
        CreatePlaylistDto req = new CreatePlaylistDto();
        req.setName("Empty Playlist");
        req.setSongIds(null);

        when(playlistRepository.save(any())).thenAnswer(inv -> {
            Playlist pl = inv.getArgument(0);
            return Playlist.builder().id(1L).user(pl.getUser()).name(pl.getName())
                    .songIdsJson("[]").createdAt(Instant.now()).updatedAt(Instant.now()).build();
        });

        PlaylistDetailDto result = service.createPlaylist(owner, req);

        assertTrue(result.getSongs().isEmpty());
    }

    @Test
    void shouldReturnPlaylistDetailDto() {
        Playlist p = Playlist.builder().id(1L).user(owner).name("Chill")
                .songIdsJson("[]").createdAt(Instant.now()).updatedAt(Instant.now()).build();
        when(playlistRepository.findById(1L)).thenReturn(Optional.of(p));

        PlaylistDetailDto result = service.getPlaylistById(1L, 1L);

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
        Playlist p = Playlist.builder().id(1L).user(owner).name("Mine")
                .songIdsJson("[]").createdAt(Instant.now()).updatedAt(Instant.now()).build();
        when(playlistRepository.findById(1L)).thenReturn(Optional.of(p));
        ResponseStatusException ex = assertThrows(ResponseStatusException.class,
                () -> service.getPlaylistById(1L, 999L));
        assertEquals(HttpStatus.FORBIDDEN, ex.getStatusCode());
    }

    @Test
    void shouldThrow403WhenUpdatingPlaylistOwnedByDifferentUser() {
        Playlist p = Playlist.builder().id(1L).user(owner).name("Mine")
                .songIdsJson("[]").createdAt(Instant.now()).updatedAt(Instant.now()).build();
        when(playlistRepository.findById(1L)).thenReturn(Optional.of(p));

        UpdatePlaylistDto req = new UpdatePlaylistDto();
        req.setName("New Name");

        ResponseStatusException ex = assertThrows(ResponseStatusException.class,
                () -> service.updatePlaylist(1L, 999L, req));
        assertEquals(HttpStatus.FORBIDDEN, ex.getStatusCode());
    }

    @Test
    void shouldNotChangePlaylistNameWhenNewNameIsNull() {
        Playlist p = Playlist.builder().id(1L).user(owner).name("Unchanged")
                .songIdsJson("[]").createdAt(Instant.now()).updatedAt(Instant.now()).build();
        when(playlistRepository.findById(1L)).thenReturn(Optional.of(p));
        when(playlistRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        UpdatePlaylistDto req = new UpdatePlaylistDto();
        req.setName(null);

        PlaylistDetailDto result = service.updatePlaylist(1L, 1L, req);

        assertEquals("Unchanged", result.getName());
    }

    @Test
    void shouldNotChangeSongIdsWhenNewSongIdsIsNull() {
        Playlist p = Playlist.builder().id(1L).user(owner).name("Mix")
                .songIdsJson("[5]").createdAt(Instant.now()).updatedAt(Instant.now()).build();
        when(playlistRepository.findById(1L)).thenReturn(Optional.of(p));
        when(playlistRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
        when(songRepository.findAllById(any())).thenReturn(List.of());

        UpdatePlaylistDto req = new UpdatePlaylistDto();
        req.setSongIds(null);

        service.updatePlaylist(1L, 1L, req);

        verify(playlistRepository).save(playlistCaptor.capture());
        assertEquals("[5]", playlistCaptor.getValue().getSongIdsJson());
    }

    @Test
    void shouldNotChangeCoverImageWhenNewCoverIsNull() {
        Playlist p = Playlist.builder().id(1L).user(owner).name("Mix")
                .coverImage("some-cover").songIdsJson("[]")
                .createdAt(Instant.now()).updatedAt(Instant.now()).build();
        when(playlistRepository.findById(1L)).thenReturn(Optional.of(p));
        when(playlistRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        UpdatePlaylistDto req = new UpdatePlaylistDto();
        req.setCoverImage(null); // null = no change

        service.updatePlaylist(1L, 1L, req);

        verify(playlistRepository).save(playlistCaptor.capture());
        assertEquals("some-cover", playlistCaptor.getValue().getCoverImage());
    }

    @Test
    void shouldSetNewCoverWhenCoverImageIsNonBlank() {
        Playlist p = Playlist.builder().id(1L).user(owner).name("Mix")
                .coverImage(null).songIdsJson("[]")
                .createdAt(Instant.now()).updatedAt(Instant.now()).build();
        when(playlistRepository.findById(1L)).thenReturn(Optional.of(p));
        when(playlistRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        UpdatePlaylistDto req = new UpdatePlaylistDto();
        req.setCoverImage("new-cover-data");

        service.updatePlaylist(1L, 1L, req);

        verify(playlistRepository).save(playlistCaptor.capture());
        assertEquals("new-cover-data", playlistCaptor.getValue().getCoverImage());
    }

    @Test
    void shouldUpdatePlaylistName() {
        Playlist p = Playlist.builder().id(1L).user(owner).name("Old Name")
                .songIdsJson("[]").createdAt(Instant.now()).updatedAt(Instant.now()).build();
        when(playlistRepository.findById(1L)).thenReturn(Optional.of(p));
        when(playlistRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        UpdatePlaylistDto req = new UpdatePlaylistDto();
        req.setName("New Name");

        PlaylistDetailDto result = service.updatePlaylist(1L, 1L, req);

        assertEquals("New Name", result.getName());
    }

    @Test
    void shouldUpdatePlaylistSongIds() {
        Playlist p = Playlist.builder().id(1L).user(owner).name("Mix")
                .songIdsJson("[]").createdAt(Instant.now()).updatedAt(Instant.now()).build();
        Song song = Song.builder().id(5L).name("New Song").songType(ContentType.STREAMABLE).fileHash("h").build();
        SongDto songDto = new SongDto();
        songDto.setId(5L);
        when(playlistRepository.findById(1L)).thenReturn(Optional.of(p));
        when(playlistRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
        when(songRepository.findAllById(List.of(5L))).thenReturn(List.of(song));
        when(songMapper.toDto(song)).thenReturn(songDto);

        UpdatePlaylistDto req = new UpdatePlaylistDto();
        req.setSongIds(List.of(5L));

        PlaylistDetailDto result = service.updatePlaylist(1L, 1L, req);

        assertEquals(1, result.getSongs().size());
    }

    @Test
    void shouldRemoveCoverImageWhenBlankCoverImageProvided() {
        Playlist p = Playlist.builder().id(1L).user(owner).name("Mix")
                .coverImage("data:img/png;base64,abc").songIdsJson("[]")
                .createdAt(Instant.now()).updatedAt(Instant.now()).build();
        when(playlistRepository.findById(1L)).thenReturn(Optional.of(p));
        when(playlistRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        UpdatePlaylistDto req = new UpdatePlaylistDto();
        req.setCoverImage("");

        service.updatePlaylist(1L, 1L, req);

        verify(playlistRepository).save(playlistCaptor.capture());
        assertNull(playlistCaptor.getValue().getCoverImage());
    }

    @Test
    void shouldDeletePlaylist() {
        Playlist p = Playlist.builder().id(1L).user(owner).name("To Delete")
                .songIdsJson("[]").createdAt(Instant.now()).updatedAt(Instant.now()).build();
        when(playlistRepository.findById(1L)).thenReturn(Optional.of(p));

        service.deletePlaylist(1L, 1L);

        verify(playlistRepository).delete(p);
    }

    @Test
    void shouldThrow403WhenDeletingPlaylistOwnedByDifferentUser() {
        Playlist p = Playlist.builder().id(1L).user(owner).name("Mine")
                .songIdsJson("[]").createdAt(Instant.now()).updatedAt(Instant.now()).build();
        when(playlistRepository.findById(1L)).thenReturn(Optional.of(p));
        assertThrows(ResponseStatusException.class, () -> service.deletePlaylist(1L, 999L));
    }

    @Test
    void shouldReturnPlaylistCoverBytes() {
        byte[] img = "img".getBytes();
        Playlist p = Playlist.builder().id(1L).user(owner).name("P")
                .coverImage(Base64.getEncoder().encodeToString(img))
                .songIdsJson("[]").createdAt(Instant.now()).updatedAt(Instant.now()).build();
        when(playlistRepository.findById(1L)).thenReturn(Optional.of(p));

        assertArrayEquals(img, service.getPlaylistCover(1L, 1L));
    }

    @Test
    void shouldThrowNotFoundWhenPlaylistHasNoCover() {
        Playlist p = Playlist.builder().id(1L).user(owner).name("P")
                .coverImage(null).songIdsJson("[]")
                .createdAt(Instant.now()).updatedAt(Instant.now()).build();
        when(playlistRepository.findById(1L)).thenReturn(Optional.of(p));
        assertThrows(ResponseStatusException.class, () -> service.getPlaylistCover(1L, 1L));
    }

    @Test
    void shouldThrow403WhenGettingPlaylistCoverOwnedByDifferentUser() {
        Playlist p = Playlist.builder().id(1L).user(owner).name("P")
                .coverImage("some-cover").songIdsJson("[]")
                .createdAt(Instant.now()).updatedAt(Instant.now()).build();
        when(playlistRepository.findById(1L)).thenReturn(Optional.of(p));
        ResponseStatusException ex = assertThrows(ResponseStatusException.class,
                () -> service.getPlaylistCover(1L, 999L));
        assertEquals(HttpStatus.FORBIDDEN, ex.getStatusCode());
    }

    @Test
    void shouldSetHasCoverTrueWhenCoverImageIsPresent() {
        Playlist p = Playlist.builder().id(1L).user(owner).name("My Mix")
                .coverImage("some-data").songIdsJson("[]")
                .createdAt(Instant.now()).updatedAt(Instant.now()).build();
        when(playlistRepository.findAllByUserId(eq(1L), any())).thenReturn(new org.springframework.data.domain.PageImpl<>(List.of(p)));

        PlaylistPageDto result = service.getPlaylists(1L, 0, 20);

        assertEquals(Boolean.TRUE, result.getContent().getFirst().getHasCover());
    }

    @Test
    void shouldSetHasCoverFalseWhenCoverImageIsBlank() {
        Playlist p = Playlist.builder().id(1L).user(owner).name("My Mix")
                .coverImage("   ").songIdsJson("[]")
                .createdAt(Instant.now()).updatedAt(Instant.now()).build();
        when(playlistRepository.findAllByUserId(eq(1L), any())).thenReturn(new org.springframework.data.domain.PageImpl<>(List.of(p)));

        PlaylistPageDto result = service.getPlaylists(1L, 0, 20);

        assertNotEquals(Boolean.TRUE, result.getContent().getFirst().getHasCover());
    }

    @Test
    void shouldHandleNullSongIdsJsonWhenGettingPlaylists() {
        Playlist p = Playlist.builder().id(1L).user(owner).name("P")
                .songIdsJson(null).createdAt(Instant.now()).updatedAt(Instant.now()).build();
        when(playlistRepository.findAllByUserId(eq(1L), any())).thenReturn(new org.springframework.data.domain.PageImpl<>(List.of(p)));

        PlaylistPageDto result = service.getPlaylists(1L, 0, 20);

        assertTrue(result.getContent().getFirst().getSongIds().isEmpty());
    }

    @Test
    void shouldHandleBlankSongIdsJsonWhenGettingPlaylists() {
        Playlist p = Playlist.builder().id(1L).user(owner).name("P")
                .songIdsJson("   ").createdAt(Instant.now()).updatedAt(Instant.now()).build();
        when(playlistRepository.findAllByUserId(eq(1L), any())).thenReturn(new org.springframework.data.domain.PageImpl<>(List.of(p)));

        PlaylistPageDto result = service.getPlaylists(1L, 0, 20);

        assertTrue(result.getContent().getFirst().getSongIds().isEmpty());
    }

    @Test
    void shouldHandleInvalidSongIdsJsonWhenGettingPlaylists() {
        Playlist p = Playlist.builder().id(1L).user(owner).name("P")
                .songIdsJson("not-valid-json").createdAt(Instant.now()).updatedAt(Instant.now()).build();
        when(playlistRepository.findAllByUserId(eq(1L), any())).thenReturn(new org.springframework.data.domain.PageImpl<>(List.of(p)));

        PlaylistPageDto result = service.getPlaylists(1L, 0, 20);

        assertTrue(result.getContent().getFirst().getSongIds().isEmpty());
    }
}
