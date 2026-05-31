package com.example.musicplayerbackend.data;

import com.example.musicplayerbackend.domain.Song;
import com.example.musicplayerbackend.domain.SongChunk;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

@Repository
public interface SongChunkRepository extends JpaRepository<SongChunk, Long> {

  Boolean existsBySongAndOrderIndex(Song song, Integer chunkIndex);

  @Query(
      "select sc from SongChunk sc join fetch sc.chunk "
          + "where sc.song = :song and sc.orderIndex = :orderIndex")
  Optional<SongChunk> findWithChunkBySongAndOrderIndex(
      @Param("song") Song song, @Param("orderIndex") Integer orderIndex);
}
