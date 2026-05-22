package com.example.musicplayerbackend.domain;

import jakarta.persistence.CascadeType;
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
import jakarta.persistence.OneToMany;
import jakarta.persistence.OrderBy;
import jakarta.persistence.Table;
import java.util.ArrayList;
import java.util.List;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "songs")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Song {

  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  private Long id;

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "artist_id", referencedColumnName = "id")
  private Artist artist;

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "album_id", referencedColumnName = "id")
  private Album album;

  @Column(nullable = false)
  private String name;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false)
  private ContentType songType;

  private Long ownerId; // null for streamable songs, user ID for user-uploaded songs

  private Integer durationInSeconds;
  private Integer trackNumber;
  private Integer discNumber;
  private Integer releaseYear;

  @Column(name = "file_hash", nullable = false, unique = true, length = 64)
  private String fileHash;

  @Builder.Default
  @OneToMany(mappedBy = "song", cascade = CascadeType.ALL, orphanRemoval = true)
  @OrderBy("orderIndex ASC")
  private List<SongChunk> chunks = new ArrayList<>();
}
