package com.example.musicplayerbackend.service;

import com.example.musicplayerbackend.data.UserPlaybackStateRepository;
import com.example.musicplayerbackend.domain.PlaybackStateDto;
import com.example.musicplayerbackend.domain.UserPlaybackState;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Captor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Instant;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class PlaybackStateServiceTest {

    @Mock
    private UserPlaybackStateRepository stateRepository;

    @Captor
    private ArgumentCaptor<UserPlaybackState> stateCaptor;

    private PlaybackStateService service;

    @BeforeEach
    void setUp() {
        service = new PlaybackStateService(stateRepository);
    }

    @Test
    void shouldCreateNewRecordWhenNoPlaybackStateExists() {
        when(stateRepository.findById(1L)).thenReturn(Optional.empty());
        when(stateRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        PlaybackStateDto req = new PlaybackStateDto();
        req.setPositionSeconds(42L);
        req.setShuffle(true);
        req.setRepeat(false);

        PlaybackStateDto result = service.saveState(1L, req);

        verify(stateRepository).save(stateCaptor.capture());
        UserPlaybackState saved = stateCaptor.getValue();

        assertEquals(1L, saved.getUserId());
        assertEquals(42L, saved.getPositionSeconds());
        assertTrue(saved.getShuffle());
        assertFalse(saved.getRepeat());

        assertEquals(42L, result.getPositionSeconds());
        assertTrue(result.getShuffle());
        assertFalse(result.getRepeat());
        assertNotNull(result.getUpdatedAt());
    }

    @Test
    void shouldMutateExistingPlaybackStateRecordRatherThanCreatingNew() {
        UserPlaybackState existing = UserPlaybackState.builder()
                .userId(1L)
                .positionSeconds(10L)
                .shuffle(false)
                .repeat(false)
                .updatedAt(Instant.now())
                .build();

        when(stateRepository.findById(1L)).thenReturn(Optional.of(existing));
        when(stateRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        PlaybackStateDto req = new PlaybackStateDto();
        req.setPositionSeconds(99L);
        req.setShuffle(true);
        req.setRepeat(true);

        service.saveState(1L, req);

        verify(stateRepository).save(stateCaptor.capture());
        UserPlaybackState saved = stateCaptor.getValue();

        assertSame(existing, saved);
        assertEquals(99L, saved.getPositionSeconds());
        assertTrue(saved.getShuffle());
        assertTrue(saved.getRepeat());
    }

    @Test
    void shouldDefaultNullShuffleAndRepeatToFalse() {
        when(stateRepository.findById(1L)).thenReturn(Optional.empty());
        when(stateRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        PlaybackStateDto req = new PlaybackStateDto();
        req.setShuffle(null);
        req.setRepeat(null);

        service.saveState(1L, req);

        verify(stateRepository).save(stateCaptor.capture());
        assertFalse(stateCaptor.getValue().getShuffle());
        assertFalse(stateCaptor.getValue().getRepeat());
    }

    @Test
    void shouldDefaultPositionSecondsToZeroWhenNull() {
        when(stateRepository.findById(1L)).thenReturn(Optional.empty());
        when(stateRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        PlaybackStateDto req = new PlaybackStateDto();
        req.setPositionSeconds(null);

        service.saveState(1L, req);

        verify(stateRepository).save(stateCaptor.capture());
        assertEquals(0L, stateCaptor.getValue().getPositionSeconds());
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
                .positionSeconds(120L)
                .shuffle(true)
                .repeat(true)
                .updatedAt(Instant.now())
                .build();

        when(stateRepository.findById(2L)).thenReturn(Optional.of(entity));

        PlaybackStateDto dto = service.getState(2L).orElseThrow();

        assertEquals(120L, dto.getPositionSeconds());
        assertTrue(dto.getShuffle());
        assertTrue(dto.getRepeat());
        assertNotNull(dto.getUpdatedAt());
    }
}
