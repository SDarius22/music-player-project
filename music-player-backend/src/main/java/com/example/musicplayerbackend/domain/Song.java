package com.example.musicplayerbackend.domain;

import jakarta.persistence.*;
import lombok.*;

import java.util.ArrayList;
import java.util.List;

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
    private SongType songType;

    private Integer ownerId; // null for streamable songs, user ID for user-uploaded songs

    private String photo;
    private Integer durationInSeconds;
    private Integer trackNumber;
    private Integer discNumber;

    @Column(name = "release_year")
    private Integer year;

    @OneToMany(mappedBy = "song", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("orderIndex ASC")
    private List<SongChunk> chunks = new ArrayList<>();
}