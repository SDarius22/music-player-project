package com.example.musicplayerbackend.components;

import com.example.musicplayerbackend.domain.PlaybackStateDto;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

import java.util.Map;

@Slf4j
@Component
@RequiredArgsConstructor
public class RedisSignalingListener {

    private final SignalingHandler signalingHandler;
    private final ObjectMapper objectMapper;

    public void onSyncTrigger(String message) {
        try {
            Long userId = Long.parseLong(message.trim());
            signalingHandler.deliverSyncTriggerLocally(userId);
        } catch (NumberFormatException e) {
            log.error("[REDIS_LISTENER] Invalid userId in sync trigger message: {}", message);
        }
    }

    @SuppressWarnings("unchecked")
    public void onPlaybackStateChanged(String message) {
        try {
            Map<String, Object> payload = objectMapper.readValue(message, Map.class);
            Long userId = ((Number) payload.get("userId")).longValue();
            PlaybackStateDto state = objectMapper.convertValue(payload.get("state"), PlaybackStateDto.class);
            signalingHandler.deliverPlaybackStateChangedLocally(userId, state);
        } catch (Exception e) {
            log.error("[REDIS_LISTENER] Failed to process playback state change: {}", e.getMessage());
        }
    }
}