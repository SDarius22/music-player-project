package com.example.musicplayerbackend.components;

import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

import com.example.musicplayerbackend.domain.WebRTCMessage;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class RedisSignalingListenerTest {

  @Mock SignalingHandler signalingHandler;

  ObjectMapper objectMapper = new ObjectMapper();
  RedisSignalingListener listener;

  @BeforeEach
  void setUp() {
    listener = new RedisSignalingListener(signalingHandler, objectMapper);
  }

  @Test
  void shouldDelegateToSignalingHandlerWhenWebRTCSignalIsValid() throws Exception {
    WebRTCMessage signal = new WebRTCMessage("OFFER", "peer-A", "peer-B", "hash-1", "sdp-offer");
    String message = objectMapper.writeValueAsString(signal);

    listener.onWebRTCSignal(message);

    verify(signalingHandler)
        .routeToTargetLocally(
            argThat(
                s ->
                    "OFFER".equals(s.type())
                        && "peer-A".equals(s.senderId())
                        && "peer-B".equals(s.targetId())
                        && "hash-1".equals(s.fileHash())));
  }

  @Test
  void shouldDelegateAnswerSignalToSignalingHandler() throws Exception {
    WebRTCMessage signal = new WebRTCMessage("ANSWER", "peer-B", "peer-A", "hash-2", "sdp-answer");
    String message = objectMapper.writeValueAsString(signal);

    listener.onWebRTCSignal(message);

    verify(signalingHandler)
        .routeToTargetLocally(
            argThat(
                s ->
                    "ANSWER".equals(s.type())
                        && "peer-B".equals(s.senderId())
                        && "peer-A".equals(s.targetId())));
  }

  @Test
  void shouldDelegateIceCandidateSignalToSignalingHandler() throws Exception {
    WebRTCMessage signal =
        new WebRTCMessage("ICE_CANDIDATE", "peer-A", "peer-B", "hash-3", "candidate-data");
    String message = objectMapper.writeValueAsString(signal);

    listener.onWebRTCSignal(message);

    verify(signalingHandler)
        .routeToTargetLocally(
            argThat(s -> "ICE_CANDIDATE".equals(s.type()) && "peer-A".equals(s.senderId())));
  }

  @Test
  void shouldNotDelegateWhenWebRTCSignalJsonIsInvalid() {
    listener.onWebRTCSignal("{invalid json}");

    verify(signalingHandler, never()).routeToTargetLocally(any());
  }
}
