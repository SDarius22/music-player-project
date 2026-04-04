package com.example.musicplayerbackend.data;

import com.example.musicplayerbackend.domain.ChunkStat;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ChunkStatRepository extends JpaRepository<ChunkStat, Long> {
    List<ChunkStat> findAllByOrderByTimestampDesc();
}
