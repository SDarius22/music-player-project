package com.example.musicplayerbackend.domain;

import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;

@Entity
@Table(name = "chunk_stats")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ChunkStat {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Instant timestamp;

    private Long userId;

    @Column(length = 64)
    private String songFileHash;

    private String songName;

    @Column(nullable = false)
    private Integer localChunks;

    @Column(nullable = false)
    private Integer localCachedChunks;

    @Column(nullable = false)
    private Integer p2pChunks;

    @Column(nullable = false)
    private Integer serverChunks;

    @Column(nullable = false)
    private Integer totalChunks;

    @Column(nullable = false)
    private Double p2pPercentage;
}
