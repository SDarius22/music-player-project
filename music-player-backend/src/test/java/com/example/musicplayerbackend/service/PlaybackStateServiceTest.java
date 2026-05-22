package com.example.musicplayerbackend.service;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.example.musicplayerbackend.data.UserPlaybackStateRepository;
import com.example.musicplayerbackend.domain.PlaybackStateDto;
import com.example.musicplayerbackend.domain.UserPlaybackState;
import java.time.Instant;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Captor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class PlaybackStateServiceTest {

  @Mock private UserPlaybackStateRepository stateRepository;

  @Captor private ArgumentCaptor<UserPlaybackState> stateCaptor;

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
    req.setAutoPlay(true);
    req.setAutoPlayRecommendationsPage(3L);

    PlaybackStateDto result = service.saveState(1L, req);

    verify(stateRepository).save(stateCaptor.capture());
    UserPlaybackState saved = stateCaptor.getValue();

    assertEquals(1L, saved.getUserId());
    assertEquals(42L, saved.getPositionSeconds());
    assertTrue(saved.getShuffle());
    assertFalse(saved.getRepeat());
    assertTrue(saved.getAutoPlay());
    assertEquals(3L, saved.getAutoPlayRecommendationsPage());

    assertEquals(42L, result.getPositionSeconds());
    assertTrue(result.getShuffle());
    assertFalse(result.getRepeat());
    assertTrue(result.getAutoPlay());
    assertEquals(3L, result.getAutoPlayRecommendationsPage());
    assertNotNull(result.getUpdatedAt());
  }

  @Test
  void shouldMutateExistingPlaybackStateRecordRatherThanCreatingNew() {
    UserPlaybackState existing =
        UserPlaybackState.builder()
            .userId(1L)
            .positionSeconds(10L)
            .shuffle(false)
            .repeat(false)
            .autoPlay(false)
            .autoPlayRecommendationsPage(0L)
            .updatedAt(Instant.now())
            .build();

    when(stateRepository.findById(1L)).thenReturn(Optional.of(existing));
    when(stateRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

    PlaybackStateDto req = new PlaybackStateDto();
    req.setPositionSeconds(99L);
    req.setShuffle(true);
    req.setRepeat(true);
    req.setAutoPlay(true);
    req.setAutoPlayRecommendationsPage(4L);

    service.saveState(1L, req);

    verify(stateRepository).save(stateCaptor.capture());
    UserPlaybackState saved = stateCaptor.getValue();

    assertSame(existing, saved);
    assertEquals(99L, saved.getPositionSeconds());
    assertTrue(saved.getShuffle());
    assertTrue(saved.getRepeat());
    assertTrue(saved.getAutoPlay());
    assertEquals(4L, saved.getAutoPlayRecommendationsPage());
  }

  @Test
  void shouldDefaultNullShuffleAndRepeatToFalse() {
    when(stateRepository.findById(1L)).thenReturn(Optional.empty());
    when(stateRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

    PlaybackStateDto req = new PlaybackStateDto();
    req.setShuffle(null);
    req.setRepeat(null);
    req.setAutoPlay(null);
    req.setAutoPlayRecommendationsPage(null);

    service.saveState(1L, req);

    verify(stateRepository).save(stateCaptor.capture());
    assertFalse(stateCaptor.getValue().getShuffle());
    assertFalse(stateCaptor.getValue().getRepeat());
    assertFalse(stateCaptor.getValue().getAutoPlay());
    assertEquals(0L, stateCaptor.getValue().getAutoPlayRecommendationsPage());
  }

  @Test
  void shouldClampNegativeAutoPlayRecommendationsPageToZero() {
    when(stateRepository.findById(1L)).thenReturn(Optional.empty());
    when(stateRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

    PlaybackStateDto req = new PlaybackStateDto();
    req.setAutoPlayRecommendationsPage(-10L);

    service.saveState(1L, req);

    verify(stateRepository).save(stateCaptor.capture());
    assertEquals(0L, stateCaptor.getValue().getAutoPlayRecommendationsPage());
  }

  @Test
  void shouldPreserveExistingAutoPlayFieldsWhenRequestOmitsThem() {
    UserPlaybackState existing =
        UserPlaybackState.builder()
            .userId(1L)
            .positionSeconds(20L)
            .shuffle(false)
            .repeat(false)
            .autoPlay(true)
            .autoPlayRecommendationsPage(9L)
            .updatedAt(Instant.now())
            .build();

    when(stateRepository.findById(1L)).thenReturn(Optional.of(existing));
    when(stateRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

    PlaybackStateDto req = new PlaybackStateDto();
    req.setPositionSeconds(30L);
    req.setShuffle(true);
    req.setRepeat(true);
    req.setAutoPlay(null);
    req.setAutoPlayRecommendationsPage(null);

    service.saveState(1L, req);

    verify(stateRepository).save(stateCaptor.capture());
    UserPlaybackState saved = stateCaptor.getValue();
    assertTrue(saved.getAutoPlay());
    assertEquals(9L, saved.getAutoPlayRecommendationsPage());
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
    UserPlaybackState entity =
        UserPlaybackState.builder()
            .userId(2L)
            .positionSeconds(120L)
            .shuffle(true)
            .repeat(true)
            .autoPlay(true)
            .autoPlayRecommendationsPage(7L)
            .updatedAt(Instant.now())
            .build();

    when(stateRepository.findById(2L)).thenReturn(Optional.of(entity));

    PlaybackStateDto dto = service.getState(2L).orElseThrow();

    assertEquals(120L, dto.getPositionSeconds());
    assertTrue(dto.getShuffle());
    assertTrue(dto.getRepeat());
    assertTrue(dto.getAutoPlay());
    assertEquals(7L, dto.getAutoPlayRecommendationsPage());
    assertNotNull(dto.getUpdatedAt());
  }
}
