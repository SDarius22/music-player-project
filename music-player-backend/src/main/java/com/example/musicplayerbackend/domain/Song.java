package com.example.musicplayerbackend.domain;

import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;

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
    private Integer id;

    @Column(nullable = false)
    private String name;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "artist_id", referencedColumnName = "id")
    private Artist artist;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "album_id", referencedColumnName = "id")
    private Album album;

    @Column(name = "photo")
    private String photo;

    @Column(name = "path", nullable = false)
    private String path;

    @Column(name = "duration_in_seconds")
    private Integer durationInSeconds;

    @Column(name = "track_number")
    private Integer trackNumber;

    @Column(name = "disc_number")
    private Integer discNumber;

    @Column(name = "release_year")
    private Integer year;

    @Column(name = "last_played")
    private Instant lastPlayed;

    @Column(name = "liked_by_user", nullable = false)
    private Boolean likedByUser;

    @Column(name = "play_count", nullable = false)
    private Integer playCount;
}