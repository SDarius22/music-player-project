package com.example.musicplayerbackend.domain;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;

@JsonIgnoreProperties(ignoreUnknown = true)
public record WebRTCMessage(
        String type,
        String senderId,
        String targetId,
        Integer songId,
        Object payload // Holds the SDP string, ICE candidate object, or a List of peer IDs
) {
}
