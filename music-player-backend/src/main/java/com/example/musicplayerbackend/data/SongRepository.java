package com.example.musicplayerbackend.data;

import com.example.musicplayerbackend.domain.Song;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface SongRepository extends JpaRepository<Song, Long>, JpaSpecificationExecutor<Song> {
    @Override
    @EntityGraph(attributePaths = {"artist", "album"})
    Optional<Song> findById(Long id);

    Optional<Song> findByFileHash(String fileHash);

    @Query(value = "SELECT * FROM music_library.songs WHERE song_type = 'STREAMABLE' ORDER BY RANDOM()", nativeQuery = true)
    List<Song> findRandomStreamable(Pageable pageable);
}