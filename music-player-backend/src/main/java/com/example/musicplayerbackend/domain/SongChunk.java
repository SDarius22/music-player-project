package com.example.musicplayerbackend.domain;

import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "song_chunks")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class SongChunk {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "song_id", nullable = false)
    private Song song;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "chunk_id", nullable = false)
    private Chunk chunk;

    @Column(nullable = false)
    private Integer orderIndex;
}