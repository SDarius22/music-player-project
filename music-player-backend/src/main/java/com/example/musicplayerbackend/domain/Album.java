package com.example.musicplayerbackend.domain;

import com.example.musicplayerbackend.helpers.EntityHashHelper;
import jakarta.persistence.*;
import lombok.*;

import java.util.HashSet;
import java.util.List;
import java.util.Set;

@Entity
@Table(name = "albums", uniqueConstraints = {
        @UniqueConstraint(columnNames = {"name"})
})
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
            inverseJoinColumns = @JoinColumn(name = "artist_id")
    )
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