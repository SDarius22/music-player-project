package com.example.musicplayerbackend.data;

import com.example.musicplayerbackend.data.projection.PlaylistListProjection;
import com.example.musicplayerbackend.domain.Playlist;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

@Repository
public interface PlaylistRepository extends JpaRepository<Playlist, Long> {

    boolean existsByUser_IdAndName(Long userId, String name);

    java.util.Optional<Playlist> findByUser_IdAndName(Long userId, String name);

    @Query(
        value = """
            SELECT p.id,
                   p.name,
                   p.playlist_type                                                       AS type,
                   p.user_id                                                             AS userid,
                   p.indestructible                                                      AS indestructible,
                   STRING_AGG(s.file_hash, ',' ORDER BY ps.position)
                       FILTER (WHERE s.file_hash IS NOT NULL AND s.file_hash <> '')      AS songfilehashescsv
            FROM music_library.playlists p
            LEFT JOIN music_library.playlist_songs ps ON ps.playlist_id = p.id
            LEFT JOIN music_library.songs s ON s.file_hash = ps.song_file_hash
            WHERE p.user_id = :userId
              AND (:q = '' OR LOWER(p.name) LIKE LOWER(CONCAT('%', :q, '%')))
              AND (CAST(:indestructibleFilter AS BOOLEAN) IS NULL OR p.indestructible = CAST(:indestructibleFilter AS BOOLEAN))
            GROUP BY p.id, p.name, p.playlist_type, p.user_id, p.indestructible, p.created_at
            """,
        countQuery = """
            SELECT COUNT(*) FROM music_library.playlists p
            WHERE p.user_id = :userId
              AND (:q = '' OR LOWER(p.name) LIKE LOWER(CONCAT('%', :q, '%')))
              AND (CAST(:indestructibleFilter AS BOOLEAN) IS NULL OR p.indestructible = CAST(:indestructibleFilter AS BOOLEAN))
            """,
        nativeQuery = true
    )
    Page<PlaylistListProjection> findAllWithHashes(
            @Param("userId") Long userId,
            @Param("q") String q,
            @Param("indestructibleFilter") Boolean indestructibleFilter,
            Pageable pageable);
}
