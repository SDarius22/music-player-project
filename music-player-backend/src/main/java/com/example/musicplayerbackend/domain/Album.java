package com.example.musicplayerbackend.domain;

import com.example.musicplayerbackend.helpers.EntityHashHelper;
import jakarta.persistence.*;
import lombok.*;

import java.util.List;

@Entity
@Table(name = "albums", uniqueConstraints = {
        @UniqueConstraint(columnNames = {"name", "artist_id"})
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

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "artist_id")
    private Artist artist;

    @OneToMany(mappedBy = "album")
    private List<Song> songs;

    @PrePersist
    @PreUpdate
    void ensureHash() {
        if (hash == null || hash.isBlank()) {
            hash = EntityHashHelper.albumHash(artist != null ? artist.getName() : null, name);
        }
    }
}