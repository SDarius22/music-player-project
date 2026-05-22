package com.example.musicplayerbackend.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "user_playback_state")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class UserPlaybackState {

  @Id private Long userId;

  @Column(nullable = false)
  @Builder.Default
  private Long positionSeconds = 0L;

  @Column(nullable = false)
  @Builder.Default
  private Boolean shuffle = false;

  @Column(nullable = false)
  @Builder.Default
  private Boolean repeat = false;

  @Column(nullable = false)
  @Builder.Default
  private Boolean autoPlay = false;

  @Column(nullable = false)
  @Builder.Default
  private Long autoPlayRecommendationsPage = 0L;

  @Column(nullable = false)
  @Builder.Default
  private Instant updatedAt = Instant.now();
}
