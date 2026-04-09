package com.example.musicplayerbackend.domain;

import com.example.musicplayerbackend.helpers.EntityHashHelper;
import jakarta.persistence.*;
import lombok.*;

import java.util.HashSet;
import java.util.List;
import java.util.Set;

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