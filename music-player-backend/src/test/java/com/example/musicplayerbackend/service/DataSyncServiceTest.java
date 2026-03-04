package com.example.musicplayerbackend.service;

import com.example.musicplayerbackend.data.SongRepository;
import com.example.musicplayerbackend.domain.Song;
import com.example.musicplayerbackend.domain.SongSyncDto;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Captor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.time.temporal.ChronoUnit;
import java.util.Collection;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class DataSyncServiceTest {

    private final int SONG_ID = 1;

    @Mock
    private SongRepository songRepository;

    @InjectMocks
    private DataSyncService dataSyncService;

    @Captor
    private ArgumentCaptor<Collection<Song>> songCollectionCaptor;

    private Song dbSong;

    @BeforeEach
    void setUp() {
        dbSong = new Song();
        dbSong.setId(SONG_ID);
        dbSong.setPlayCount(10);
        dbSong.setLikedByUser(false);
        dbSong.setLastPlayed(Instant.now().minus(5, ChronoUnit.DAYS));
    }

    @Test
    void shouldApplyAdditivePlayCountDelta() {
        SongSyncDto request = new SongSyncDto();
        request.setSongId(SONG_ID);
        request.setPlayCountDelta(3);
        request.setLikedByUser(false);
        request.setLastPlayed(OffsetDateTime.now(ZoneOffset.UTC));

        when(songRepository.findAllById(List.of(SONG_ID))).thenReturn(List.of(dbSong));

        dataSyncService.syncOfflineData(List.of(request));

        verify(songRepository).saveAll(songCollectionCaptor.capture());

        List<Song> savedSongs = songCollectionCaptor.getValue().stream().toList();
        assertEquals(1, savedSongs.size());

        Song savedSong = savedSongs.getFirst();
        assertEquals(13, savedSong.getPlayCount(), "Play count delta was not added correctly.");
    }

    @Test
    void shouldUpdateStateIfClientTimestampIsNewer() {
        OffsetDateTime newerTime = OffsetDateTime.now(ZoneOffset.UTC).minusDays(1);

        SongSyncDto request = new SongSyncDto();
        request.setSongId(SONG_ID);
        request.setPlayCountDelta(0);
        request.setLikedByUser(true);
        request.setLastPlayed(newerTime);

        when(songRepository.findAllById(List.of(SONG_ID))).thenReturn(List.of(dbSong));

        dataSyncService.syncOfflineData(List.of(request));

        verify(songRepository).saveAll(songCollectionCaptor.capture());

        Song savedSong = songCollectionCaptor.getValue().stream().toList().getFirst();
        assertTrue(savedSong.getLikedByUser(), "Newer offline state was rejected incorrectly.");
        assertEquals(newerTime.toInstant(), savedSong.getLastPlayed(), "Last played timestamp was not updated.");
    }

    @Test
    void shouldIgnoreStateIfClientTimestampIsOlder() {
        OffsetDateTime olderTime = OffsetDateTime.now(ZoneOffset.UTC).minusDays(10);

        SongSyncDto request = new SongSyncDto();
        request.setSongId(SONG_ID);
        request.setPlayCountDelta(2);
        request.setLikedByUser(true);
        request.setLastPlayed(olderTime);

        when(songRepository.findAllById(List.of(SONG_ID))).thenReturn(List.of(dbSong));

        dataSyncService.syncOfflineData(List.of(request));

        verify(songRepository).saveAll(songCollectionCaptor.capture());

        Song savedSong = songCollectionCaptor.getValue().stream().toList().getFirst();
        assertEquals(12, savedSong.getPlayCount(), "Additive delta must still apply even if state is stale.");
        assertFalse(savedSong.getLikedByUser(), "Stale offline state overwrote newer database state.");
        assertNotEquals(olderTime.toInstant(), savedSong.getLastPlayed(), "Stale timestamp overwrote newer database timestamp.");
    }

    @Test
    void shouldIgnoreUnknownSongsGracefully() {
        SongSyncDto request = new SongSyncDto();
        request.setSongId(999);
        request.setPlayCountDelta(5);

        when(songRepository.findAllById(List.of(999))).thenReturn(List.of());

        dataSyncService.syncOfflineData(List.of(request));

        verify(songRepository).saveAll(songCollectionCaptor.capture());
        assertTrue(songCollectionCaptor.getValue().isEmpty(), "Service attempted to save an unknown entity.");
    }
}
