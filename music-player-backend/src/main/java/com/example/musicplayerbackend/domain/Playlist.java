package com.example.musicplayerbackend.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import java.time.Instant;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(
    name = "playlists",
    uniqueConstraints =
        @UniqueConstraint(
            name = "uq_playlists_user_id_name",
            columnNames = {"user_id", "name"}))
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Playlist {

  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  private Long id;

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "user_id", nullable = false)
  private User user;

  @Column(nullable = false)
  private String name;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false)
  @Builder.Default
  private ContentType playlistType = ContentType.USER_UPLOAD;

  @Column(columnDefinition = "TEXT")
  private String coverImage;

  @Column(nullable = false)
  @Builder.Default
  private Boolean indestructible = false;

  @Column(nullable = false)
  @Builder.Default
  private Instant createdAt = Instant.now();

  @Column(nullable = false)
  @Builder.Default
  private Instant updatedAt = Instant.now();
}
