package com.example.musicplayerbackend.domain;

import jakarta.persistence.Column;
import jakarta.persistence.EmbeddedId;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.MapsId;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "user_library")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class UserLibrary {

  @EmbeddedId private UserLibraryID id;

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

  @Builder.Default private Boolean isDownloadedLocally = false;

  @Column(nullable = false)
  private Instant lastUpdated;

  @Builder.Default
  @Column(nullable = false)
  private Boolean isDeleted = false;
}
