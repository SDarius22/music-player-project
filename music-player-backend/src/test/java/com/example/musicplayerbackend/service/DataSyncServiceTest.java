package com.example.musicplayerbackend.service;

import com.example.musicplayerbackend.components.SignalingHandler;
import com.example.musicplayerbackend.data.SongRepository;
import com.example.musicplayerbackend.data.UserLibraryRepository;
import com.example.musicplayerbackend.data.UserRepository;
import com.example.musicplayerbackend.domain.*;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
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

    @InjectMocks
    DataSyncService dataSyncService;

    @Test
    void shouldReturnServerChangesWhenNoLastSyncTimeAndNoLocalChanges() {
        Long userId = 10L;
        Song song = Song.builder().id(7L).fileHash("file-hash").name("Song").songType(ContentType.STREAMABLE).build();
        UserLibrary entry = UserLibrary.builder()
                .id(new UserLibraryID(userId, song.getId()))
                .song(song)
                .liked(true)
                .isDeleted(false)
                .playCount(4L)
                .totalPlayDurationSeconds(22L)
                .lastPlayed(Instant.parse("2026-01-01T00:00:00Z"))
                .addedAt(Instant.parse("2025-12-31T00:00:00Z"))
                .lastUpdated(Instant.parse("2026-01-01T00:00:05Z"))
                .build();

        when(userLibraryRepository.findByIdUserIdAndIsDeletedFalse(userId)).thenReturn(List.of(entry));

        SyncRequestDto request = new SyncRequestDto();
        SyncResponseDto response = dataSyncService.performSync(userId, request);

        assertNotNull(response.getNewSyncTime());
        assertFalse(response.getHasMore());
        assertEquals(1, response.getServerChanges().size());
        SongSyncDto dto = response.getServerChanges().getFirst();
        assertEquals("file-hash", dto.getFileHash());
        assertTrue(dto.getLikedByUser());
        assertFalse(dto.getIsDeleted());
        assertEquals(0, dto.getPlayCountDelta());
        assertEquals(22L, dto.getTotalPlayDurationSeconds());
        assertEquals(OffsetDateTime.parse("2026-01-01T00:00:00Z"), dto.getLastPlayed());
        assertEquals(OffsetDateTime.parse("2025-12-31T00:00:00Z"), dto.getAddedAt());

        verify(userLibraryRepository).findByIdUserIdAndIsDeletedFalse(userId);
        verify(userLibraryRepository, never()).findByIdUserIdAndLastUpdatedAfter(any(), any());
        verify(signalingHandler, never()).sendSyncTrigger(any());
    }

    @Test
    void shouldApplyNewClientChangeAndTriggerSync() {
        Long userId = 11L;
        Song song = Song.builder().id(8L).fileHash("client-file").name("Song").songType(ContentType.STREAMABLE).build();
        User user = User.builder().id(userId).email("sync@example.com").role(Role.USER).provider(AuthProvider.LOCAL).build();

        SongSyncDto change = new SongSyncDto("client-file");
        change.setLikedByUser(true);
        change.setIsDeleted(false);
        change.setPlayCountDelta(2);
        change.setTotalPlayDurationSeconds(30L);
        change.setLastPlayed(OffsetDateTime.parse("2026-03-01T10:15:30Z"));
        change.setAddedAt(OffsetDateTime.parse("2026-03-01T10:00:00Z"));

        SyncRequestDto request = new SyncRequestDto();
        request.setLastSyncTime(OffsetDateTime.now(ZoneOffset.UTC).minusMinutes(1));
        request.setLocalChanges(List.of(change));

        when(userRepository.getReferenceById(userId)).thenReturn(user);
        when(songRepository.findByFileHash("client-file")).thenReturn(Optional.of(song));
        when(userLibraryRepository.findById(any(UserLibraryID.class))).thenReturn(Optional.empty());
        when(userLibraryRepository.findByIdUserIdAndLastUpdatedAfter(eq(userId), any())).thenReturn(List.of());

        SyncResponseDto response = dataSyncService.performSync(userId, request);

        assertNotNull(response.getNewSyncTime());
        assertTrue(response.getServerChanges().isEmpty());

        ArgumentCaptor<UserLibrary> captor = ArgumentCaptor.forClass(UserLibrary.class);
        verify(userLibraryRepository).save(captor.capture());
        UserLibrary saved = captor.getValue();

        assertEquals(userId, saved.getId().getUserId());
        assertEquals(song.getId(), saved.getId().getSongId());
        assertEquals(song, saved.getSong());
        assertEquals(user, saved.getUser());
        assertTrue(saved.getLiked());
        assertFalse(saved.getIsDeleted());
        assertEquals(2L, saved.getPlayCount());
        assertEquals(30L, saved.getTotalPlayDurationSeconds());
        assertEquals(Instant.parse("2026-03-01T10:15:30Z"), saved.getLastPlayed());
        assertEquals(Instant.parse("2026-03-01T10:00:00Z"), saved.getAddedAt());
        assertNotNull(saved.getLastUpdated());

        verify(signalingHandler).sendSyncTrigger(userId);
        verify(userLibraryRepository).findByIdUserIdAndLastUpdatedAfter(eq(userId), any());
    }

    @Test
    void shouldMarkExistingEntryDeletedAndSkipUnknownSongs() {
        Long userId = 12L;
        Song knownSong = Song.builder().id(9L).fileHash("known").name("Known").songType(ContentType.STREAMABLE).build();
        User existingUser = User.builder().id(userId).email("existing@example.com").role(Role.USER).provider(AuthProvider.LOCAL).build();

        UserLibrary existing = UserLibrary.builder()
                .id(new UserLibraryID(userId, knownSong.getId()))
                .user(existingUser)
                .song(knownSong)
                .liked(true)
                .isDeleted(false)
                .playCount(5L)
                .totalPlayDurationSeconds(99L)
                .lastUpdated(Instant.parse("2026-01-01T00:00:00Z"))
                .build();

        SongSyncDto unknown = new SongSyncDto("missing");
        unknown.setIsDeleted(false);

        SongSyncDto deleteKnown = new SongSyncDto("known");
        deleteKnown.setIsDeleted(true);

        SyncRequestDto request = new SyncRequestDto();
        request.setLocalChanges(List.of(unknown, deleteKnown));

        when(userRepository.getReferenceById(userId)).thenReturn(existingUser);
        when(songRepository.findByFileHash("missing")).thenReturn(Optional.empty());
        when(songRepository.findByFileHash("known")).thenReturn(Optional.of(knownSong));
        when(userLibraryRepository.findById(any(UserLibraryID.class))).thenReturn(Optional.of(existing));
        when(userLibraryRepository.findByIdUserIdAndIsDeletedFalse(userId)).thenReturn(List.of());

        dataSyncService.performSync(userId, request);

        verify(userLibraryRepository, times(1)).save(existing);
        assertTrue(existing.getIsDeleted());
        assertEquals(5L, existing.getPlayCount());
        assertEquals(99L, existing.getTotalPlayDurationSeconds());
        assertNotNull(existing.getLastUpdated());
        verify(signalingHandler).sendSyncTrigger(userId);
    }

    @Test
    void shouldSkipSaveWhenSongDisappearsDuringEntryCreation() {
        Long userId = 13L;
        Song song = Song.builder().id(10L).fileHash("race").name("Race").songType(ContentType.STREAMABLE).build();
        User user = User.builder().id(userId).email("race@example.com").role(Role.USER).provider(AuthProvider.LOCAL).build();

        SongSyncDto change = new SongSyncDto("race");
        change.setIsDeleted(false);

        SyncRequestDto request = new SyncRequestDto();
        request.setLocalChanges(List.of(change));

        when(userRepository.getReferenceById(userId)).thenReturn(user);
        when(songRepository.findByFileHash("race")).thenReturn(Optional.of(song), Optional.empty());
        when(userLibraryRepository.findById(any(UserLibraryID.class))).thenReturn(Optional.empty());
        when(userLibraryRepository.findByIdUserIdAndIsDeletedFalse(userId)).thenReturn(List.of());

        dataSyncService.performSync(userId, request);

        verify(userLibraryRepository, never()).save(any());
        verify(signalingHandler).sendSyncTrigger(userId);
    }

    @Test
    void shouldUseLastSyncQueryAndNotTriggerWhenNoLocalChanges() {
        Long userId = 14L;
        Song song = Song.builder().id(20L).fileHash("sync-only").name("Sync Only").songType(ContentType.STREAMABLE).build();
        UserLibrary entry = UserLibrary.builder()
                .id(new UserLibraryID(userId, song.getId()))
                .song(song)
                .liked(false)
                .isDeleted(false)
                .totalPlayDurationSeconds(0L)
                .lastUpdated(Instant.now())
                .build();

        SyncRequestDto request = new SyncRequestDto();
        request.setLastSyncTime(OffsetDateTime.now(ZoneOffset.UTC).minusMinutes(5));
        request.setLocalChanges(List.of());

        when(userLibraryRepository.findByIdUserIdAndLastUpdatedAfter(eq(userId), any())).thenReturn(List.of(entry));

        SyncResponseDto response = dataSyncService.performSync(userId, request);

        assertEquals(1, response.getServerChanges().size());
        assertEquals("sync-only", response.getServerChanges().getFirst().getFileHash());
        verify(userLibraryRepository).findByIdUserIdAndLastUpdatedAfter(eq(userId), any());
        verify(userLibraryRepository, never()).findByIdUserIdAndIsDeletedFalse(any());
        verify(signalingHandler, never()).sendSyncTrigger(any());
    }

    @Test
    void shouldResetDeletedFlagButPreserveFieldsWhenNoPositiveDeltasOrTimestamps() {
        Long userId = 15L;
        Song song = Song.builder().id(21L).fileHash("preserve").name("Preserve").songType(ContentType.STREAMABLE).build();
        User user = User.builder().id(userId).email("preserve@example.com").role(Role.USER).provider(AuthProvider.LOCAL).build();

        Instant existingLastPlayed = Instant.parse("2026-01-10T00:00:00Z");
        Instant existingAddedAt = Instant.parse("2026-01-09T00:00:00Z");

        UserLibrary existing = UserLibrary.builder()
                .id(new UserLibraryID(userId, song.getId()))
                .user(user)
                .song(song)
                .liked(false)
                .isDeleted(true)
                .playCount(10L)
                .totalPlayDurationSeconds(50L)
                .lastPlayed(existingLastPlayed)
                .addedAt(existingAddedAt)
                .lastUpdated(Instant.parse("2026-01-11T00:00:00Z"))
                .build();

        SongSyncDto change = new SongSyncDto("preserve");
        change.setIsDeleted(false);
        change.setLikedByUser(null);
        change.setPlayCountDelta(0);
        change.setTotalPlayDurationSeconds(-10L);
        change.setLastPlayed(null);
        change.setAddedAt(null);

        SyncRequestDto request = new SyncRequestDto();
        request.setLocalChanges(List.of(change));

        when(userRepository.getReferenceById(userId)).thenReturn(user);
        when(songRepository.findByFileHash("preserve")).thenReturn(Optional.of(song));
        when(userLibraryRepository.findById(any(UserLibraryID.class))).thenReturn(Optional.of(existing));
        when(userLibraryRepository.findByIdUserIdAndIsDeletedFalse(userId)).thenReturn(List.of(existing));

        dataSyncService.performSync(userId, request);

        verify(userLibraryRepository).save(existing);
        assertFalse(existing.getIsDeleted());
        assertFalse(existing.getLiked());
        assertEquals(10L, existing.getPlayCount());
        assertEquals(50L, existing.getTotalPlayDurationSeconds());
        assertEquals(existingLastPlayed, existing.getLastPlayed());
        assertEquals(existingAddedAt, existing.getAddedAt());
    }

    @Test
    void shouldMapEntityWithoutSongAndWithoutDates() {
        Long userId = 16L;
        UserLibrary entry = UserLibrary.builder()
                .id(new UserLibraryID(userId, 999L))
                .song(null)
                .liked(true)
                .isDeleted(true)
                .totalPlayDurationSeconds(12L)
                .lastUpdated(Instant.now())
                .build();

        when(userLibraryRepository.findByIdUserIdAndIsDeletedFalse(userId)).thenReturn(List.of(entry));

        SyncRequestDto request = new SyncRequestDto();
        SyncResponseDto response = dataSyncService.performSync(userId, request);

        SongSyncDto dto = response.getServerChanges().getFirst();
        assertNull(dto.getFileHash());
        assertTrue(dto.getLikedByUser());
        assertTrue(dto.getIsDeleted());
        assertNull(dto.getLastPlayed());
        assertNull(dto.getAddedAt());
        assertEquals(12L, dto.getTotalPlayDurationSeconds());
    }
}

