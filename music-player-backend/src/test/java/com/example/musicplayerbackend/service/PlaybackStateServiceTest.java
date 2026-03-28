package com.example.musicplayerbackend.service;

import com.example.musicplayerbackend.components.SignalingHandler;
import com.example.musicplayerbackend.data.UserPlaybackStateRepository;
import com.example.musicplayerbackend.domain.PlaybackStateDto;
import com.example.musicplayerbackend.domain.UserPlaybackState;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Captor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class PlaybackStateServiceTest {

    @Mock
    private UserPlaybackStateRepository stateRepository;

    @Mock
    private SignalingHandler signalingHandler;

    @Captor
    private ArgumentCaptor<UserPlaybackState> stateCaptor;

    private PlaybackStateService service;

    @BeforeEach
    void setUp() {
        service = new PlaybackStateService(stateRepository, signalingHandler, new ObjectMapper());
    }

    @Test
    void shouldCreateNewRecordWhenNoPlaybackStateExists() {
        when(stateRepository.findById(1L)).thenReturn(Optional.empty());
        when(stateRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        PlaybackStateDto req = new PlaybackStateDto();
        req.setQueueSongIds(List.of(10L, 20L, 30L));
        req.setCurrentSongId(20L);
        req.setPositionMs(5_000L);
        req.setShuffle(true);
        req.setRepeat(false);

        PlaybackStateDto result = service.saveState(1L, req);

        verify(stateRepository).save(stateCaptor.capture());
        UserPlaybackState saved = stateCaptor.getValue();

        assertEquals(1L, saved.getUserId());
        assertEquals(20L, saved.getCurrentSongId());
        assertEquals(5_000L, saved.getPositionMs());
        assertTrue(saved.getShuffle());
        assertFalse(saved.getRepeat());

        assertEquals(20L, result.getCurrentSongId());
        assertEquals(3, result.getQueueSongIds().size());
        assertTrue(result.getShuffle());
        assertFalse(result.getRepeat());
        assertNotNull(result.getUpdatedAt());
    }

    @Test
    void shouldMutateExistingPlaybackStateRecordRatherThanCreatingNew() {
        UserPlaybackState existing = UserPlaybackState.builder()
                .userId(1L)
                .queueSongIds("[1]")
                .currentSongId(1L)
                .positionMs(1_000L)
                .shuffle(false)
                .repeat(false)
                .updatedAt(Instant.now())
                .build();

        when(stateRepository.findById(1L)).thenReturn(Optional.of(existing));
        when(stateRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        PlaybackStateDto req = new PlaybackStateDto();
        req.setQueueSongIds(List.of(5L, 6L));
        req.setCurrentSongId(6L);
        req.setPositionMs(9_000L);
        req.setShuffle(true);
        req.setRepeat(true);

        service.saveState(1L, req);

        verify(stateRepository).save(stateCaptor.capture());
        UserPlaybackState saved = stateCaptor.getValue();

        assertSame(existing, saved);
        assertEquals(6L, saved.getCurrentSongId());
        assertEquals(9_000L, saved.getPositionMs());
        assertTrue(saved.getShuffle());
        assertTrue(saved.getRepeat());
    }

    @Test
    void shouldDefaultNullShuffleAndRepeatToFalse() {
        when(stateRepository.findById(1L)).thenReturn(Optional.empty());
        when(stateRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        PlaybackStateDto req = new PlaybackStateDto();
        req.setQueueSongIds(List.of());
        req.setShuffle(null);
        req.setRepeat(null);

        service.saveState(1L, req);

        verify(stateRepository).save(stateCaptor.capture());
        assertFalse(stateCaptor.getValue().getShuffle());
        assertFalse(stateCaptor.getValue().getRepeat());
    }

    @Test
    void shouldNotifySignalingHandlerAfterPersistingState() {
        when(stateRepository.findById(1L)).thenReturn(Optional.empty());
        when(stateRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        service.saveState(1L, new PlaybackStateDto());

        verify(signalingHandler).sendPlaybackStateChanged(eq(1L), any(PlaybackStateDto.class));
    }

    @Test
    void shouldDefaultPositionMsToZeroWhenNull() {
        when(stateRepository.findById(1L)).thenReturn(Optional.empty());
        when(stateRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        PlaybackStateDto req = new PlaybackStateDto();
        req.setPositionMs(null); // null → 0L

        service.saveState(1L, req);

        verify(stateRepository).save(stateCaptor.capture());
        assertEquals(0L, stateCaptor.getValue().getPositionMs());
    }

    @Test
    void shouldSerializeEmptyJsonWhenQueueSongIdsIsNull() {
        when(stateRepository.findById(1L)).thenReturn(Optional.empty());
        when(stateRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        PlaybackStateDto req = new PlaybackStateDto();
        req.setQueueSongIds(null); // null → List.of() → "[]"

        service.saveState(1L, req);

        verify(stateRepository).save(stateCaptor.capture());
        assertEquals("[]", stateCaptor.getValue().getQueueSongIds());
    }

    @Test
    void shouldReturnEmptyQueueWhenQueueSongIdsIsNull() {
        UserPlaybackState entity = UserPlaybackState.builder()
                .userId(1L).queueSongIds(null).currentSongId(1L)
                .positionMs(0L).shuffle(false).repeat(false).updatedAt(Instant.now()).build();
        when(stateRepository.findById(1L)).thenReturn(Optional.of(entity));

        PlaybackStateDto dto = service.getState(1L).orElseThrow();

        assertTrue(dto.getQueueSongIds().isEmpty());
    }

    @Test
    void shouldReturnEmptyQueueWhenQueueSongIdsIsBlank() {
        UserPlaybackState entity = UserPlaybackState.builder()
                .userId(1L).queueSongIds("   ").currentSongId(1L)
                .positionMs(0L).shuffle(false).repeat(false).updatedAt(Instant.now()).build();
        when(stateRepository.findById(1L)).thenReturn(Optional.of(entity));

        PlaybackStateDto dto = service.getState(1L).orElseThrow();

        assertTrue(dto.getQueueSongIds().isEmpty());
    }

    @Test
    void shouldReturnEmptyQueueWhenQueueSongIdsIsInvalidJson() {
        UserPlaybackState entity = UserPlaybackState.builder()
                .userId(1L).queueSongIds("not-valid-json").currentSongId(1L)
                .positionMs(0L).shuffle(false).repeat(false).updatedAt(Instant.now()).build();
        when(stateRepository.findById(1L)).thenReturn(Optional.of(entity));

        PlaybackStateDto dto = service.getState(1L).orElseThrow();

        assertTrue(dto.getQueueSongIds().isEmpty());
    }

    @Test
    void shouldReturnEmptyWhenNoPlaybackStateRecordExists() {
        when(stateRepository.findById(99L)).thenReturn(Optional.empty());
        assertTrue(service.getState(99L).isEmpty());
    }

    @Test
    void shouldMapAllFieldsIncludingShuffleAndRepeat() {
        UserPlaybackState entity = UserPlaybackState.builder()
                .userId(2L)
                .queueSongIds("[100, 200]")
                .currentSongId(200L)
                .positionMs(12_000L)
                .shuffle(true)
                .repeat(true)
                .updatedAt(Instant.now())
                .build();

        when(stateRepository.findById(2L)).thenReturn(Optional.of(entity));

        PlaybackStateDto dto = service.getState(2L).orElseThrow();

        assertEquals(List.of(100L, 200L), dto.getQueueSongIds());
        assertEquals(200L, dto.getCurrentSongId());
        assertEquals(12_000L, dto.getPositionMs());
        assertTrue(dto.getShuffle());
        assertTrue(dto.getRepeat());
        assertNotNull(dto.getUpdatedAt());
    }
}
