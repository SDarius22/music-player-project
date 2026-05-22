package com.example.musicplayerbackend.domain;

import com.example.musicplayerbackend.helpers.EntityHashHelper;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.JoinTable;
import jakarta.persistence.ManyToMany;
import jakarta.persistence.OneToMany;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(
    name = "albums",
    uniqueConstraints = {@UniqueConstraint(columnNames = {"name"})})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Album {

  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  private Long id;

  @Column(nullable = false)
  private String name;

  @Column(nullable = false, unique = true)
  private String hash;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false)
  @Builder.Default
  private ContentType albumType = ContentType.STREAMABLE;

  private Long ownerId; // null for streamable albums, user ID for user-uploaded albums
  private String coverImage; // base64 encoded image

  @Builder.Default
  @ManyToMany
  @JoinTable(
      name = "album_artists",
      joinColumns = @JoinColumn(name = "album_id"),
      inverseJoinColumns = @JoinColumn(name = "artist_id"))
  private Set<Artist> artists = new HashSet<>();

  @OneToMany(mappedBy = "album")
  private List<Song> songs;

  @PrePersist
  @PreUpdate
  void ensureHash() {
    if (hash == null || hash.isBlank()) {
      hash = EntityHashHelper.albumHash(name);
    }
  }
}
