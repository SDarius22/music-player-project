package com.example.musicplayerbackend.data;

import com.example.musicplayerbackend.domain.Chunk;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface ChunkRepository extends JpaRepository<Chunk, Long> {
    Optional<Chunk> findByContentHash(String contentHash);
}
