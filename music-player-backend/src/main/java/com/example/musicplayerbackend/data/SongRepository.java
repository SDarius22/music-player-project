package com.example.musicplayerbackend.data;

import com.example.musicplayerbackend.domain.Song;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface SongRepository extends JpaRepository<Song, Integer> {

    @Override
    @EntityGraph(attributePaths = {"artist", "album"})
    List<Song> findAll();

    @Override
    @EntityGraph(attributePaths = {"artist", "album"})
    Optional<Song> findById(Integer id);

    @Query("SELECT s.id FROM Song s ORDER BY s.playCount DESC")
    List<Integer> findTopPlayedSongIds(Pageable pageable);
}