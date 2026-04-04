package com.example.musicplayerbackend.components;

import com.example.musicplayerbackend.domain.PlaybackStateDto;
import com.example.musicplayerbackend.domain.WebRTCMessage;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.argThat;
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

    @Test
    void shouldDelegateToSignalingHandlerWhenWebRTCSignalIsValid() throws Exception {
        WebRTCMessage signal = new WebRTCMessage("OFFER", "peer-A", "peer-B", "hash-1", "sdp-offer");
        String message = objectMapper.writeValueAsString(signal);

        listener.onWebRTCSignal(message);

        verify(signalingHandler).routeToTargetLocally(argThat(s ->
                "OFFER".equals(s.type()) &&
                "peer-A".equals(s.senderId()) &&
                "peer-B".equals(s.targetId()) &&
                "hash-1".equals(s.songId())
        ));
    }

    @Test
    void shouldDelegateAnswerSignalToSignalingHandler() throws Exception {
        WebRTCMessage signal = new WebRTCMessage("ANSWER", "peer-B", "peer-A", "hash-2", "sdp-answer");
        String message = objectMapper.writeValueAsString(signal);

        listener.onWebRTCSignal(message);

        verify(signalingHandler).routeToTargetLocally(argThat(s ->
                "ANSWER".equals(s.type()) && "peer-B".equals(s.senderId()) && "peer-A".equals(s.targetId())
        ));
    }

    @Test
    void shouldDelegateIceCandidateSignalToSignalingHandler() throws Exception {
        WebRTCMessage signal = new WebRTCMessage("ICE_CANDIDATE", "peer-A", "peer-B", "hash-3", "candidate-data");
        String message = objectMapper.writeValueAsString(signal);

        listener.onWebRTCSignal(message);

        verify(signalingHandler).routeToTargetLocally(argThat(s ->
                "ICE_CANDIDATE".equals(s.type()) && "peer-A".equals(s.senderId())
        ));
    }

    @Test
    void shouldNotDelegateWhenWebRTCSignalJsonIsInvalid() {
        listener.onWebRTCSignal("{invalid json}");

        verify(signalingHandler, never()).routeToTargetLocally(any());
    }
}
