package com.example.musicplayerbackend.domain;

import jakarta.persistence.*;
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
    @Column(name = "user_id")
    private Long userId;

    /** JSON array of song IDs representing the queue, e.g. [1, 5, 12]. */
    @Column(name = "queue_song_ids", columnDefinition = "TEXT", nullable = false)
    @Builder.Default
    private String queueSongIds = "[]";

    @Column(name = "current_song_id")
    private Long currentSongId;

    @Column(name = "position_ms", nullable = false)
    @Builder.Default
    private Long positionMs = 0L;

    @Column(name = "updated_at", nullable = false)
    @Builder.Default
    private Instant updatedAt = Instant.now();
}
