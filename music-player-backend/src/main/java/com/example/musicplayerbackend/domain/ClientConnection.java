package com.example.musicplayerbackend.domain;

import org.springframework.web.socket.WebSocketSession;

public record ClientConnection(
        WebSocketSession session,
        String peerId,
        Long userId
) {
}