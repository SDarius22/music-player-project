package com.example.musicplayerbackend.domain;

import com.example.musicplayerbackend.helpers.EntityHashHelper;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.ManyToMany;
import jakarta.persistence.OneToMany;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "artists")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Artist {

  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  private Long id;

  @Column(nullable = false, unique = true)
  private String name;

  @Column(nullable = false, unique = true)
  private String hash;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false)
  @Builder.Default
  private ContentType artistType = ContentType.STREAMABLE;

  private Long ownerId; // null for streamable artists, user ID for user-uploaded artists

  @Builder.Default
  @ManyToMany(mappedBy = "artists", fetch = FetchType.LAZY)
  private Set<Album> albums = new HashSet<>();

  @OneToMany(mappedBy = "artist", fetch = FetchType.LAZY)
  private List<Song> songs;

  @PrePersist
  @PreUpdate
  void ensureHash() {
    if (hash == null || hash.isBlank()) {
      hash = EntityHashHelper.artistHash(name);
    }
  }
}
