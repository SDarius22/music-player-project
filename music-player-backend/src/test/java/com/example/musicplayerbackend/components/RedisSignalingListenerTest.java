package com.example.musicplayerbackend.components;

import com.example.musicplayerbackend.domain.PlaybackStateDto;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

@ExtendWith(MockitoExtension.class)
class RedisSignalingListenerTest {

    @Mock
    SignalingHandler signalingHandler;

    ObjectMapper objectMapper = new ObjectMapper();
    RedisSignalingListener listener;

    @BeforeEach
    void setUp() {
        listener = new RedisSignalingListener(signalingHandler, objectMapper);
    }

    @Test
    void shouldDelegateToSignalingHandlerWhenUserIdIsValid() {
        listener.onSyncTrigger("42");

        verify(signalingHandler).deliverSyncTriggerLocally(42L);
    }

    @Test
    void shouldTrimAndParseUserIdWithLeadingTrailingSpaces() {
        listener.onSyncTrigger("  99  ");

        verify(signalingHandler).deliverSyncTriggerLocally(99L);
    }

    @Test
    void shouldNotDelegateWhenSyncTriggerUserIdIsInvalid() {
        listener.onSyncTrigger("not-a-number");

        verify(signalingHandler, never()).deliverSyncTriggerLocally(any());
    }

    @Test
    void shouldDelegateToSignalingHandlerWhenPlaybackStateJsonIsValid() throws Exception {
        PlaybackStateDto state = new PlaybackStateDto();
        String message = objectMapper.writeValueAsString(
                java.util.Map.of("userId", 7, "state", state));

        listener.onPlaybackStateChanged(message);

        verify(signalingHandler).deliverPlaybackStateChangedLocally(eq(7L), any(PlaybackStateDto.class));
    }

    @Test
    void shouldNotDelegateWhenPlaybackStateJsonIsInvalid() {
        listener.onPlaybackStateChanged("{invalid json}");

        verify(signalingHandler, never()).deliverPlaybackStateChangedLocally(any(), any());
    }

    @Test
    void shouldNotDelegateWhenPlaybackStateUserIdIsMissing() throws Exception {
        // userId is missing → payload.get("userId") is null → NullPointerException caught
        String message = objectMapper.writeValueAsString(
                java.util.Map.of("state", new PlaybackStateDto()));

        listener.onPlaybackStateChanged(message);

        verify(signalingHandler, never()).deliverPlaybackStateChangedLocally(any(), any());
    }
}
