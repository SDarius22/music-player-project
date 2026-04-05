package com.example.musicplayerbackend.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.*;

import java.time.Instant;

@Entity
@Table(name = "user_playback_state")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class UserPlaybackState {

    @Id
    private Long userId;

    @Column(columnDefinition = "TEXT", nullable = false)
    @Builder.Default
    private String queueSongIds = "[]";

    @Column(length = 64)
    private String currentFileHash;

    @Column(nullable = false)
    @Builder.Default
    private Long positionMs = 0L;

    @Column(nullable = false)
    @Builder.Default
    private Boolean shuffle = false;

    @Column(nullable = false)
    @Builder.Default
    private Boolean repeat = false;

    @Column(nullable = false)
    @Builder.Default
    private Instant updatedAt = Instant.now();
}
