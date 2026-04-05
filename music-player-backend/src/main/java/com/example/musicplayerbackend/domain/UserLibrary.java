package com.example.musicplayerbackend.domain;

import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;

@Entity
@Table(name = "user_library")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class UserLibrary {

    @EmbeddedId
    private UserLibraryID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @MapsId("songId")
    @JoinColumn(name = "song_id")
    private Song song;

    @ManyToOne(fetch = FetchType.LAZY)
    @MapsId("userId")
    @JoinColumn(name = "user_id")
    private User user;

    @Builder.Default
    @Column(nullable = false)
    private Boolean liked = false;

    @Builder.Default
    @Column(nullable = false)
    private Long playCount = 0L;

    @Builder.Default
    @Column(nullable = false)
    private Long totalPlayDurationSeconds = 0L;

    private Instant lastPlayed;

    private Instant addedAt;

    @Builder.Default
    private Boolean isDownloadedLocally = false;

    @Column(nullable = false)
    private Instant lastUpdated;

    @Builder.Default
    @Column(nullable = false)
    private Boolean isDeleted = false;
}