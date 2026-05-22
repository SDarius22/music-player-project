package com.example.musicplayerbackend.data;

import com.example.musicplayerbackend.domain.ChunkStat;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface ChunkStatRepository extends JpaRepository<ChunkStat, Long> {
  List<ChunkStat> findAllByOrderByTimestampDesc();
}
