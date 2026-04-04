package com.example.musicplayerbackend.data;

import com.example.musicplayerbackend.domain.Song;
import org.springframework.data.domain.Page;
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

    @EntityGraph(attributePaths = {"artist", "album"})
    Optional<Song> findByFileHash(String fileHash);

    List<Song> findAllByFileHashIn(List<String> fileHashes);

    @Query(value = "SELECT * FROM music_library.songs WHERE song_type = 'STREAMABLE' ORDER BY RANDOM()", nativeQuery = true)
    List<Song> findRandomStreamable(Pageable pageable);

    @EntityGraph(attributePaths = {"artist", "album"})
    @Query("SELECT s FROM Song s WHERE " +
            "(LOWER(s.name) LIKE LOWER(CONCAT('%', :q, '%')) OR " +
            "LOWER(s.artist.name) LIKE LOWER(CONCAT('%', :q, '%')) OR " +
            "LOWER(s.album.name) LIKE LOWER(CONCAT('%', :q, '%'))) AND " +
            "(s.ownerId = :userId OR s.ownerId IS NULL)")
    Page<Song> findVisibleToUser(String q, Long userId, Pageable pageable);
}