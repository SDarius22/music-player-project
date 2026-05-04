package com.example.musicplayerbackend.components;

import com.example.musicplayerbackend.domain.WebRTCMessage;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

@Slf4j
@Component
@RequiredArgsConstructor
public class RedisSignalingListener {

    private final SignalingHandler signalingHandler;
    private final ObjectMapper objectMapper;

    public void onWebRTCSignal(String message) {
        try {
            WebRTCMessage signal = objectMapper.readValue(message, WebRTCMessage.class);
            signalingHandler.routeToTargetLocally(signal);
        } catch (Exception e) {
            log.error("[REDIS_LISTENER] Failed to process WebRTC signal: {}", e.getMessage());
        }
    }
}
