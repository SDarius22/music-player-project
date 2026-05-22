package com.example.musicplayerbackend.controller;

import com.example.musicplayerbackend.domain.PlaybackStateDto;
import com.example.musicplayerbackend.domain.User;
import com.example.musicplayerbackend.service.PlaybackStateService;
import java.util.Objects;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class PlaybackStateController implements PlaybackApi {

  private final PlaybackStateService playbackStateService;

  @Override
  public ResponseEntity<PlaybackStateDto> getPlaybackState() {
    Long userId = currentUser().getId();
    return playbackStateService
        .getState(userId)
        .map(ResponseEntity::ok)
        .orElse(ResponseEntity.noContent().build());
  }

  @Override
  public ResponseEntity<PlaybackStateDto> savePlaybackState(PlaybackStateDto body) {
    Long userId = currentUser().getId();
    return ResponseEntity.ok(playbackStateService.saveState(userId, body));
  }

  private User currentUser() {
    return (User)
        Objects.requireNonNull(SecurityContextHolder.getContext().getAuthentication())
            .getPrincipal();
  }
}
