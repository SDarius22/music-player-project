package com.example.musicplayerbackend.service;

import com.example.musicplayerbackend.components.SignalingHandler;
import com.example.musicplayerbackend.data.SongRepository;
import com.example.musicplayerbackend.data.UserLibraryRepository;
import com.example.musicplayerbackend.data.UserRepository;
import com.example.musicplayerbackend.domain.*;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Captor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class DataSyncServiceTest {

    @Mock
    UserLibraryRepository userLibraryRepository;
    @Mock
    SongRepository songRepository;
    @Mock
    UserRepository userRepository;
    @Mock
    SignalingHandler signalingHandler;

    @Captor
    ArgumentCaptor<UserLibrary> libCaptor;

    DataSyncService service;
    User user;
    Song song;

    @BeforeEach
    void setUp() {
        service = new DataSyncService(userLibraryRepository, songRepository,
                userRepository, signalingHandler);
        user = User.builder().id(1L).email("u@t.com").role(Role.USER)
                .provider(AuthProvider.LOCAL).build();
        song = Song.builder().id(10L).name("Song").songType(ContentType.STREAMABLE).fileHash("h").build();
    }

    @Test
    void shouldReturnAllEntriesWhenLastSyncTimeIsNull() {
        UserLibrary entry = UserLibrary.builder()
                .id(new UserLibraryID(1L, 10L)).song(song).user(user)
                .liked(true).playCount(3L).isDeleted(false)
                .lastUpdated(Instant.now()).build();
        when(userLibraryRepository.findByIdUserIdAndIsDeletedFalse(1L)).thenReturn(List.of(entry));

        SyncRequestDto req = new SyncRequestDto();
        SyncResponseDto response = service.performSync(1L, req);

        assertNotNull(response.getNewSyncTime());
        assertEquals(1, response.getServerChanges().size());
        assertEquals(10L, response.getServerChanges().getFirst().getSongId());
    }

    @Test
    void shouldReturnOnlyUpdatedEntriesWhenLastSyncTimeIsSet() {
        Instant lastSync = Instant.now().minusSeconds(60);
        UserLibrary entry = UserLibrary.builder()
                .id(new UserLibraryID(1L, 10L)).song(song).user(user)
                .liked(false).playCount(1L).isDeleted(false)
                .lastUpdated(Instant.now()).build();
        when(userLibraryRepository.findByIdUserIdAndLastUpdatedAfter(eq(1L), any()))
                .thenReturn(List.of(entry));

        SyncRequestDto req = new SyncRequestDto();
        req.setLastSyncTime(OffsetDateTime.ofInstant(lastSync, ZoneOffset.UTC));
        service.performSync(1L, req);

        verify(userLibraryRepository).findByIdUserIdAndLastUpdatedAfter(eq(1L), any());
    }

    @Test
    void shouldApplyLikedChangeWhenSyncing() {
        UserLibraryID id = new UserLibraryID(1L, 10L);
        UserLibrary existing = UserLibrary.builder()
                .id(id).song(song).user(user)
                .liked(false).playCount(0L).isDeleted(false)
                .lastUpdated(Instant.now()).build();
        when(userLibraryRepository.findByIdUserIdAndIsDeletedFalse(1L)).thenReturn(List.of());
        when(userRepository.getReferenceById(1L)).thenReturn(user);
        when(userLibraryRepository.findById(any())).thenReturn(Optional.of(existing));
        when(userLibraryRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        SongSyncDto change = new SongSyncDto();
        change.setSongId(10L);
        change.setLikedByUser(true);
        change.setIsDeleted(false);
        SyncRequestDto req = new SyncRequestDto();
        req.setLocalChanges(List.of(change));
        service.performSync(1L, req);

        verify(userLibraryRepository).save(libCaptor.capture());
        assertTrue(libCaptor.getValue().getLiked());
    }

    @Test
    void shouldApplyPlayCountDeltaWhenSyncing() {
        UserLibraryID id = new UserLibraryID(1L, 10L);
        UserLibrary existing = UserLibrary.builder()
                .id(id).song(song).user(user)
                .liked(false).playCount(5L).isDeleted(false)
                .lastUpdated(Instant.now()).build();
        when(userLibraryRepository.findByIdUserIdAndIsDeletedFalse(1L)).thenReturn(List.of());
        when(userRepository.getReferenceById(1L)).thenReturn(user);
        when(userLibraryRepository.findById(any())).thenReturn(Optional.of(existing));
        when(userLibraryRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        SongSyncDto change = new SongSyncDto();
        change.setSongId(10L);
        change.setPlayCountDelta(3);
        change.setIsDeleted(false);
        SyncRequestDto req = new SyncRequestDto();
        req.setLocalChanges(List.of(change));
        service.performSync(1L, req);

        verify(userLibraryRepository).save(libCaptor.capture());
        assertEquals(8L, libCaptor.getValue().getPlayCount());
    }

    @Test
    void shouldMarkEntryAsDeletedWhenSyncing() {
        UserLibraryID id = new UserLibraryID(1L, 10L);
        UserLibrary existing = UserLibrary.builder()
                .id(id).song(song).user(user)
                .liked(true).playCount(2L).isDeleted(false)
                .lastUpdated(Instant.now()).build();
        when(userLibraryRepository.findByIdUserIdAndIsDeletedFalse(1L)).thenReturn(List.of());
        when(userRepository.getReferenceById(1L)).thenReturn(user);
        when(userLibraryRepository.findById(any())).thenReturn(Optional.of(existing));
        when(userLibraryRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        SongSyncDto change = new SongSyncDto();
        change.setSongId(10L);
        change.setIsDeleted(true);
        SyncRequestDto req = new SyncRequestDto();
        req.setLocalChanges(List.of(change));
        service.performSync(1L, req);

        verify(userLibraryRepository).save(libCaptor.capture());
        assertTrue(libCaptor.getValue().getIsDeleted());
    }

    @Test
    void shouldCreateNewLibraryEntryWhenNotExists() {
        when(userLibraryRepository.findByIdUserIdAndIsDeletedFalse(1L)).thenReturn(List.of());
        when(userRepository.getReferenceById(1L)).thenReturn(user);
        when(userLibraryRepository.findById(any())).thenReturn(Optional.empty());
        when(songRepository.findById(10L)).thenReturn(Optional.of(song));
        when(userLibraryRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        SongSyncDto change = new SongSyncDto();
        change.setSongId(10L);
        change.setLikedByUser(true);
        change.setIsDeleted(false);
        SyncRequestDto req = new SyncRequestDto();
        req.setLocalChanges(List.of(change));
        service.performSync(1L, req);

        verify(userLibraryRepository).save(libCaptor.capture());
        assertTrue(libCaptor.getValue().getLiked());
    }

    @Test
    void shouldSkipChangeWhenSongNotFound() {
        when(userLibraryRepository.findByIdUserIdAndIsDeletedFalse(1L)).thenReturn(List.of());
        when(userRepository.getReferenceById(1L)).thenReturn(user);
        when(userLibraryRepository.findById(any())).thenReturn(Optional.empty());
        when(songRepository.findById(999L)).thenReturn(Optional.empty());

        SongSyncDto change = new SongSyncDto();
        change.setSongId(999L);
        change.setIsDeleted(false);
        SyncRequestDto req = new SyncRequestDto();
        req.setLocalChanges(List.of(change));
        service.performSync(1L, req);

        verify(userLibraryRepository, never()).save(any());
    }

    @Test
    void shouldTriggerSignalingWhenLocalChangesArePresent() {
        when(userLibraryRepository.findByIdUserIdAndIsDeletedFalse(1L)).thenReturn(List.of());
        when(userRepository.getReferenceById(1L)).thenReturn(user);
        when(userLibraryRepository.findById(any())).thenReturn(Optional.empty());
        when(songRepository.findById(anyLong())).thenReturn(Optional.empty());

        SongSyncDto change = new SongSyncDto();
        change.setSongId(10L);
        change.setIsDeleted(false);
        SyncRequestDto req = new SyncRequestDto();
        req.setLocalChanges(List.of(change));
        service.performSync(1L, req);

        verify(signalingHandler).sendSyncTrigger(1L);
    }

    @Test
    void shouldNotTriggerSignalingWhenNoLocalChanges() {
        when(userLibraryRepository.findByIdUserIdAndIsDeletedFalse(1L)).thenReturn(List.of());

        SyncRequestDto req = new SyncRequestDto();
        service.performSync(1L, req);

        verify(signalingHandler, never()).sendSyncTrigger(any());
    }

    @Test
    void shouldNotTriggerSignalingWhenLocalChangesIsEmptyList() {
        when(userLibraryRepository.findByIdUserIdAndIsDeletedFalse(1L)).thenReturn(List.of());

        SyncRequestDto req = new SyncRequestDto();
        req.setLocalChanges(new ArrayList<>()); // non-null but empty

        service.performSync(1L, req);

        verify(signalingHandler, never()).sendSyncTrigger(any());
        verify(userLibraryRepository, never()).save(any());
    }

    // ── applyClientChanges branches ───────────────────────────────────────────

    @Test
    void shouldNotChangeLikedWhenLikedByUserIsNull() {
        UserLibrary existing = UserLibrary.builder()
                .id(new UserLibraryID(1L, 10L)).song(song).user(user)
                .liked(false).playCount(0L).isDeleted(false)
                .lastUpdated(Instant.now()).build();
        when(userLibraryRepository.findByIdUserIdAndIsDeletedFalse(1L)).thenReturn(List.of());
        when(userRepository.getReferenceById(1L)).thenReturn(user);
        when(userLibraryRepository.findById(any())).thenReturn(Optional.of(existing));
        when(userLibraryRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        SongSyncDto change = new SongSyncDto();
        change.setSongId(10L);
        change.setLikedByUser(null); // null → no change
        change.setIsDeleted(false);

        SyncRequestDto req = new SyncRequestDto();
        req.setLocalChanges(List.of(change));
        service.performSync(1L, req);

        verify(userLibraryRepository).save(libCaptor.capture());
        assertFalse(libCaptor.getValue().getLiked()); // unchanged
    }

    @Test
    void shouldNotChangePlayCountWhenDeltaIsZero() {
        UserLibrary existing = UserLibrary.builder()
                .id(new UserLibraryID(1L, 10L)).song(song).user(user)
                .liked(false).playCount(7L).isDeleted(false)
                .lastUpdated(Instant.now()).build();
        when(userLibraryRepository.findByIdUserIdAndIsDeletedFalse(1L)).thenReturn(List.of());
        when(userRepository.getReferenceById(1L)).thenReturn(user);
        when(userLibraryRepository.findById(any())).thenReturn(Optional.of(existing));
        when(userLibraryRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        SongSyncDto change = new SongSyncDto();
        change.setSongId(10L);
        change.setPlayCountDelta(0); // zero → no increment
        change.setIsDeleted(false);

        SyncRequestDto req = new SyncRequestDto();
        req.setLocalChanges(List.of(change));
        service.performSync(1L, req);

        verify(userLibraryRepository).save(libCaptor.capture());
        assertEquals(7L, libCaptor.getValue().getPlayCount()); // unchanged
    }

    @Test
    void shouldNotChangePlayCountWhenDeltaIsNegative() {
        UserLibrary existing = UserLibrary.builder()
                .id(new UserLibraryID(1L, 10L)).song(song).user(user)
                .liked(false).playCount(5L).isDeleted(false)
                .lastUpdated(Instant.now()).build();
        when(userLibraryRepository.findByIdUserIdAndIsDeletedFalse(1L)).thenReturn(List.of());
        when(userRepository.getReferenceById(1L)).thenReturn(user);
        when(userLibraryRepository.findById(any())).thenReturn(Optional.of(existing));
        when(userLibraryRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        SongSyncDto change = new SongSyncDto();
        change.setSongId(10L);
        change.setPlayCountDelta(-3); // negative → no increment
        change.setIsDeleted(false);

        SyncRequestDto req = new SyncRequestDto();
        req.setLocalChanges(List.of(change));
        service.performSync(1L, req);

        verify(userLibraryRepository).save(libCaptor.capture());
        assertEquals(5L, libCaptor.getValue().getPlayCount()); // unchanged
    }

    @Test
    void shouldSetLastPlayedWhenProvided() {
        UserLibrary existing = UserLibrary.builder()
                .id(new UserLibraryID(1L, 10L)).song(song).user(user)
                .liked(false).playCount(0L).isDeleted(false)
                .lastUpdated(Instant.now()).build();
        when(userLibraryRepository.findByIdUserIdAndIsDeletedFalse(1L)).thenReturn(List.of());
        when(userRepository.getReferenceById(1L)).thenReturn(user);
        when(userLibraryRepository.findById(any())).thenReturn(Optional.of(existing));
        when(userLibraryRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        OffsetDateTime played = OffsetDateTime.now(ZoneOffset.UTC).minusHours(1);
        SongSyncDto change = new SongSyncDto();
        change.setSongId(10L);
        change.setLastPlayed(played);
        change.setIsDeleted(false);

        SyncRequestDto req = new SyncRequestDto();
        req.setLocalChanges(List.of(change));
        service.performSync(1L, req);

        verify(userLibraryRepository).save(libCaptor.capture());
        assertNotNull(libCaptor.getValue().getLastPlayed());
        assertEquals(played.toInstant(), libCaptor.getValue().getLastPlayed());
    }

    @Test
    void shouldSetAddedAtWhenProvided() {
        UserLibrary existing = UserLibrary.builder()
                .id(new UserLibraryID(1L, 10L)).song(song).user(user)
                .liked(false).playCount(0L).isDeleted(false)
                .lastUpdated(Instant.now()).build();
        when(userLibraryRepository.findByIdUserIdAndIsDeletedFalse(1L)).thenReturn(List.of());
        when(userRepository.getReferenceById(1L)).thenReturn(user);
        when(userLibraryRepository.findById(any())).thenReturn(Optional.of(existing));
        when(userLibraryRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        OffsetDateTime addedAt = OffsetDateTime.now(ZoneOffset.UTC).minusDays(1);
        SongSyncDto change = new SongSyncDto();
        change.setSongId(10L);
        change.setAddedAt(addedAt);
        change.setIsDeleted(false);

        SyncRequestDto req = new SyncRequestDto();
        req.setLocalChanges(List.of(change));
        service.performSync(1L, req);

        verify(userLibraryRepository).save(libCaptor.capture());
        assertEquals(addedAt.toInstant(), libCaptor.getValue().getAddedAt());
    }

    @Test
    void shouldUndeleteEntryWhenIsDeletedFalseOnPreviouslyDeletedEntry() {
        UserLibrary existing = UserLibrary.builder()
                .id(new UserLibraryID(1L, 10L)).song(song).user(user)
                .liked(false).playCount(0L).isDeleted(true) // previously deleted
                .lastUpdated(Instant.now()).build();
        when(userLibraryRepository.findByIdUserIdAndIsDeletedFalse(1L)).thenReturn(List.of());
        when(userRepository.getReferenceById(1L)).thenReturn(user);
        when(userLibraryRepository.findById(any())).thenReturn(Optional.of(existing));
        when(userLibraryRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        SongSyncDto change = new SongSyncDto();
        change.setSongId(10L);
        change.setIsDeleted(false); // un-delete

        SyncRequestDto req = new SyncRequestDto();
        req.setLocalChanges(List.of(change));
        service.performSync(1L, req);

        verify(userLibraryRepository).save(libCaptor.capture());
        assertFalse(libCaptor.getValue().getIsDeleted()); // un-deleted
    }

    @Test
    void shouldNotSetSongIdWhenMappingEntityToDtoWithNullSong() {
        UserLibrary entry = UserLibrary.builder()
                .id(new UserLibraryID(1L, 10L))
                .song(null) // null song
                .user(user)
                .liked(false).playCount(0L).isDeleted(false)
                .lastUpdated(Instant.now()).build();
        when(userLibraryRepository.findByIdUserIdAndIsDeletedFalse(1L)).thenReturn(List.of(entry));

        SyncRequestDto req = new SyncRequestDto();
        SyncResponseDto response = service.performSync(1L, req);

        assertEquals(1, response.getServerChanges().size());
        assertNull(response.getServerChanges().getFirst().getSongId());
    }

    @Test
    void shouldSetLastPlayedWhenMappingEntityToDtoAndLastPlayedNotNull() {
        Instant played = Instant.now().minusSeconds(3600);
        UserLibrary entry = UserLibrary.builder()
                .id(new UserLibraryID(1L, 10L)).song(song).user(user)
                .liked(false).playCount(0L).isDeleted(false)
                .lastPlayed(played)
                .lastUpdated(Instant.now()).build();
        when(userLibraryRepository.findByIdUserIdAndIsDeletedFalse(1L)).thenReturn(List.of(entry));

        SyncRequestDto req = new SyncRequestDto();
        SyncResponseDto response = service.performSync(1L, req);

        assertNotNull(response.getServerChanges().getFirst().getLastPlayed());
        assertEquals(played, response.getServerChanges().getFirst().getLastPlayed().toInstant());
    }

    @Test
    void shouldSetAddedAtWhenMappingEntityToDtoAndAddedAtNotNull() {
        Instant addedAt = Instant.now().minus(7, ChronoUnit.DAYS);
        UserLibrary entry = UserLibrary.builder()
                .id(new UserLibraryID(1L, 10L)).song(song).user(user)
                .liked(false).playCount(0L).isDeleted(false)
                .addedAt(addedAt)
                .lastUpdated(Instant.now()).build();
        when(userLibraryRepository.findByIdUserIdAndIsDeletedFalse(1L)).thenReturn(List.of(entry));

        SyncRequestDto req = new SyncRequestDto();
        SyncResponseDto response = service.performSync(1L, req);

        assertNotNull(response.getServerChanges().getFirst().getAddedAt());
        assertEquals(addedAt, response.getServerChanges().getFirst().getAddedAt().toInstant());
    }
}
