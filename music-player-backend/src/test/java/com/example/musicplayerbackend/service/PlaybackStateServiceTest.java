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
        req.setQueueFileHashes(List.of("hash10", "hash20", "hash30"));
        req.setCurrentFileHash("hash20");
        req.setPositionMs(5_000L);
        req.setShuffle(true);
        req.setRepeat(false);

        PlaybackStateDto result = service.saveState(1L, req);

        verify(stateRepository).save(stateCaptor.capture());
        UserPlaybackState saved = stateCaptor.getValue();

        assertEquals(1L, saved.getUserId());
        assertEquals("hash20", saved.getCurrentFileHash());
        assertEquals(5_000L, saved.getPositionMs());
        assertTrue(saved.getShuffle());
        assertFalse(saved.getRepeat());

        assertEquals("hash20", result.getCurrentFileHash());
        assertEquals(3, result.getQueueFileHashes().size());
        assertTrue(result.getShuffle());
        assertFalse(result.getRepeat());
        assertNotNull(result.getUpdatedAt());
    }

    @Test
    void shouldMutateExistingPlaybackStateRecordRatherThanCreatingNew() {
        UserPlaybackState existing = UserPlaybackState.builder()
                .userId(1L)
                .queueSongIds("[\"hash1\"]")
                .currentFileHash("hash1")
                .positionMs(1_000L)
                .shuffle(false)
                .repeat(false)
                .updatedAt(Instant.now())
                .build();

        when(stateRepository.findById(1L)).thenReturn(Optional.of(existing));
        when(stateRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        PlaybackStateDto req = new PlaybackStateDto();
        req.setQueueFileHashes(List.of("hash5", "hash6"));
        req.setCurrentFileHash("hash6");
        req.setPositionMs(9_000L);
        req.setShuffle(true);
        req.setRepeat(true);

        service.saveState(1L, req);

        verify(stateRepository).save(stateCaptor.capture());
        UserPlaybackState saved = stateCaptor.getValue();

        assertSame(existing, saved);
        assertEquals("hash6", saved.getCurrentFileHash());
        assertEquals(9_000L, saved.getPositionMs());
        assertTrue(saved.getShuffle());
        assertTrue(saved.getRepeat());
    }

    @Test
    void shouldDefaultNullShuffleAndRepeatToFalse() {
        when(stateRepository.findById(1L)).thenReturn(Optional.empty());
        when(stateRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        PlaybackStateDto req = new PlaybackStateDto();
        req.setQueueFileHashes(List.of());
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
    void shouldSerializeEmptyJsonWhenQueueFileHashesIsNull() {
        when(stateRepository.findById(1L)).thenReturn(Optional.empty());
        when(stateRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        PlaybackStateDto req = new PlaybackStateDto();
        req.setQueueFileHashes(null); // null → List.of() → "[]"

        service.saveState(1L, req);

        verify(stateRepository).save(stateCaptor.capture());
        assertEquals("[]", stateCaptor.getValue().getQueueSongIds());
    }

    @Test
    void shouldReturnEmptyQueueWhenQueueSongIdsIsNull() {
        UserPlaybackState entity = UserPlaybackState.builder()
                .userId(1L).queueSongIds(null).currentFileHash("hash1")
                .positionMs(0L).shuffle(false).repeat(false).updatedAt(Instant.now()).build();
        when(stateRepository.findById(1L)).thenReturn(Optional.of(entity));

        PlaybackStateDto dto = service.getState(1L).orElseThrow();

        assertTrue(dto.getQueueFileHashes().isEmpty());
    }

    @Test
    void shouldReturnEmptyQueueWhenQueueSongIdsIsBlank() {
        UserPlaybackState entity = UserPlaybackState.builder()
                .userId(1L).queueSongIds("   ").currentFileHash("hash1")
                .positionMs(0L).shuffle(false).repeat(false).updatedAt(Instant.now()).build();
        when(stateRepository.findById(1L)).thenReturn(Optional.of(entity));

        PlaybackStateDto dto = service.getState(1L).orElseThrow();

        assertTrue(dto.getQueueFileHashes().isEmpty());
    }

    @Test
    void shouldReturnEmptyQueueWhenQueueSongIdsIsInvalidJson() {
        UserPlaybackState entity = UserPlaybackState.builder()
                .userId(1L).queueSongIds("not-valid-json").currentFileHash("hash1")
                .positionMs(0L).shuffle(false).repeat(false).updatedAt(Instant.now()).build();
        when(stateRepository.findById(1L)).thenReturn(Optional.of(entity));

        PlaybackStateDto dto = service.getState(1L).orElseThrow();

        assertTrue(dto.getQueueFileHashes().isEmpty());
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
                .queueSongIds("[\"hash100\", \"hash200\"]")
                .currentFileHash("hash200")
                .positionMs(12_000L)
                .shuffle(true)
                .repeat(true)
                .updatedAt(Instant.now())
                .build();

        when(stateRepository.findById(2L)).thenReturn(Optional.of(entity));

        PlaybackStateDto dto = service.getState(2L).orElseThrow();

        assertEquals(List.of("hash100", "hash200"), dto.getQueueFileHashes());
        assertEquals("hash200", dto.getCurrentFileHash());
        assertEquals(12_000L, dto.getPositionMs());
        assertTrue(dto.getShuffle());
        assertTrue(dto.getRepeat());
        assertNotNull(dto.getUpdatedAt());
    }
}
