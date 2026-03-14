package com.example.musicplayerbackend.data;

import com.example.musicplayerbackend.domain.Song;
import com.example.musicplayerbackend.domain.SongType;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface SongRepository extends JpaRepository<Song, Long>, JpaSpecificationExecutor<Song> {

    @EntityGraph(attributePaths = {"artist", "album"})
    List<Song> findAllBySongType(SongType songType);

    @EntityGraph(attributePaths = {"artist", "album"})
    default List<Song> findAllStreamable() {
        return findAllBySongType(SongType.STREAMABLE);
    }

    @Override
    @EntityGraph(attributePaths = {"artist", "album"})
    Optional<Song> findById(Long id);

    Optional<Song> findByFileHash(String fileHash);
}