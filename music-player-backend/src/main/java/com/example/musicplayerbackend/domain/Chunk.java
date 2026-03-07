package com.example.musicplayerbackend.domain;

import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "chunks")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Chunk {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true, length = 64)
    private String contentHash;

    @Column(nullable = false)
    private Integer size;

    @Column(nullable = false)
    private String storagePath;
}