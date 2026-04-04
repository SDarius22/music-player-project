package com.example.musicplayerbackend.service;

import com.example.musicplayerbackend.components.SignalingHandler;
import com.example.musicplayerbackend.data.UserPlaybackStateRepository;
import com.example.musicplayerbackend.domain.PlaybackStateDto;
import com.example.musicplayerbackend.domain.UserPlaybackState;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

@Slf4j
@Service
@RequiredArgsConstructor
public class PlaybackStateService {

    private final UserPlaybackStateRepository stateRepository;
    private final SignalingHandler signalingHandler;
    private final ObjectMapper objectMapper;

    public Optional<PlaybackStateDto> getState(Long userId) {
        return stateRepository.findById(userId).map(this::toDto);
    }

    @Transactional
    public PlaybackStateDto saveState(Long userId, PlaybackStateDto req) {
        List<String> queueHashes = req.getQueueFileHashes() == null ? List.of() : req.getQueueFileHashes();

        UserPlaybackState state = stateRepository.findById(userId)
                .orElseGet(() -> UserPlaybackState.builder().userId(userId).build());

        state.setQueueSongIds(toJson(queueHashes));
        state.setCurrentFileHash(req.getCurrentFileHash());
        state.setPositionMs(req.getPositionMs() == null ? 0L : req.getPositionMs());
        state.setShuffle(req.getShuffle() != null ? req.getShuffle() : false);
        state.setRepeat(req.getRepeat() != null ? req.getRepeat() : false);
        state.setUpdatedAt(Instant.now());

        UserPlaybackState saved = stateRepository.save(state);
        PlaybackStateDto result = toDto(saved);

        // Notify other sessions of the same user to refresh their playback state.
        signalingHandler.sendPlaybackStateChanged(userId, result);

        return result;
    }

    // ── helpers ───────────────────────────────────────────────────────────────

    private PlaybackStateDto toDto(UserPlaybackState s) {
        PlaybackStateDto dto = new PlaybackStateDto();
        dto.setQueueFileHashes(fromJson(s.getQueueSongIds()));
        dto.setCurrentFileHash(s.getCurrentFileHash());
        dto.setPositionMs(s.getPositionMs());
        dto.setShuffle(s.getShuffle());
        dto.setRepeat(s.getRepeat());
        dto.setUpdatedAt(OffsetDateTime.ofInstant(s.getUpdatedAt(), ZoneOffset.UTC));
        return dto;
    }

    private String toJson(List<String> hashes) {
        try {
            return objectMapper.writeValueAsString(hashes == null ? new ArrayList<>() : hashes);
        } catch (JsonProcessingException e) {
            return "[]";
        }
    }

    private List<String> fromJson(String json) {
        if (json == null || json.isBlank()) return List.of();
        try {
            return objectMapper.readValue(json, new TypeReference<>() {});
        } catch (JsonProcessingException e) {
            return List.of();
        }
    }
}
