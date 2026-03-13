package com.example.musicplayerbackend.data;

import com.example.musicplayerbackend.domain.Song;
import com.example.musicplayerbackend.domain.SongChunk;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface SongChunkRepository extends JpaRepository<SongChunk, Long> {
    Boolean existsBySongAndOrderIndex(Song song, Integer chunkIndex);
}