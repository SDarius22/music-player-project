package com.example.musicplayerbackend.data;

import com.example.musicplayerbackend.domain.Chunk;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface ChunkRepository extends JpaRepository<Chunk, Long> {
  Optional<Chunk> findByContentHash(String contentHash);
}
