package com.example.musicplayerbackend.service;

import com.example.musicplayerbackend.data.UserPlaybackStateRepository;
import com.example.musicplayerbackend.domain.PlaybackStateDto;
import com.example.musicplayerbackend.domain.UserPlaybackState;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Optional;

@Slf4j
@Service
@RequiredArgsConstructor
public class PlaybackStateService {

    private final UserPlaybackStateRepository stateRepository;

    public Optional<PlaybackStateDto> getState(Long userId) {
        return stateRepository.findById(userId).map(this::toDto);
    }

    @Transactional
    public PlaybackStateDto saveState(Long userId, PlaybackStateDto req) {
        UserPlaybackState state = stateRepository.findById(userId)
                .orElseGet(() -> UserPlaybackState.builder().userId(userId).build());

        state.setPositionSeconds(req.getPositionSeconds() == null ? 0L : req.getPositionSeconds());
        state.setShuffle(req.getShuffle() != null ? req.getShuffle() : false);
        state.setRepeat(req.getRepeat() != null ? req.getRepeat() : false);
        if (req.getAutoPlay() != null) {
            state.setAutoPlay(req.getAutoPlay());
        } else if (state.getAutoPlay() == null) {
            state.setAutoPlay(false);
        }
        if (req.getAutoPlayRecommendationsPage() != null) {
            state.setAutoPlayRecommendationsPage(Math.max(0L, req.getAutoPlayRecommendationsPage()));
        } else if (state.getAutoPlayRecommendationsPage() == null) {
            state.setAutoPlayRecommendationsPage(0L);
        }
        state.setUpdatedAt(Instant.now());

        return toDto(stateRepository.save(state));
    }

    private PlaybackStateDto toDto(UserPlaybackState s) {
        PlaybackStateDto dto = new PlaybackStateDto();
        dto.setPositionSeconds(s.getPositionSeconds());
        dto.setShuffle(s.getShuffle());
        dto.setRepeat(s.getRepeat());
        dto.setAutoPlay(s.getAutoPlay());
        dto.setAutoPlayRecommendationsPage(s.getAutoPlayRecommendationsPage());
        dto.setUpdatedAt(OffsetDateTime.ofInstant(s.getUpdatedAt(), ZoneOffset.UTC));
        return dto;
    }
}
