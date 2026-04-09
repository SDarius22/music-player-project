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

    @Query(
        value = """
            SELECT p.id,
                   p.name,
                   p.playlist_type                                                       AS type,
                   p.user_id                                                             AS userid,
                   STRING_AGG(s.file_hash, ',' ORDER BY ps.position)
                       FILTER (WHERE s.file_hash IS NOT NULL AND s.file_hash <> '')      AS songfilehashescsv
            FROM music_library.playlists p
            LEFT JOIN music_library.playlist_songs ps ON ps.playlist_id = p.id
            LEFT JOIN music_library.songs s ON s.id = ps.song_id
            WHERE p.user_id = :userId
            GROUP BY p.id, p.name, p.playlist_type, p.user_id
            """,
        countQuery = """
            SELECT COUNT(*) FROM music_library.playlists p WHERE p.user_id = :userId
            """,
        nativeQuery = true
    )
    Page<PlaylistListProjection> findAllWithHashes(@Param("userId") Long userId, Pageable pageable);
}
