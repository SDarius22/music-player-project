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

    /** JSON array of file hashes representing the queue. */
    @Column(name = "queue_song_ids", columnDefinition = "TEXT", nullable = false)
    @Builder.Default
    private String queueSongIds = "[]";

    @Column(name = "current_file_hash", length = 64)
    private String currentFileHash;

    @Column(name = "position_ms", nullable = false)
    @Builder.Default
    private Long positionMs = 0L;

    @Column(name = "shuffle", nullable = false)
    @Builder.Default
    private Boolean shuffle = false;

    @Column(name = "repeat", nullable = false)
    @Builder.Default
    private Boolean repeat = false;

    @Column(name = "updated_at", nullable = false)
    @Builder.Default
    private Instant updatedAt = Instant.now();
}
