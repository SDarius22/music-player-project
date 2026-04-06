package com.example.musicplayerbackend.data;

import com.example.musicplayerbackend.data.projection.AlbumListProjection;
import com.example.musicplayerbackend.domain.Album;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface AlbumRepository extends JpaRepository<Album, Long> {
    Optional<Album> findByHash(String hash);

    @Query(
            value = """
                    SELECT a.name,
                           ar.name           AS artistname,
                           STRING_AGG(s.file_hash, ',' ORDER BY s.disc_number, s.track_number)
                               FILTER (WHERE s.file_hash IS NOT NULL AND s.file_hash <> '') AS songfilehashescsv
                    FROM music_library.albums a
                    LEFT JOIN music_library.artists ar ON ar.id = a.artist_id
                    LEFT JOIN music_library.songs s ON s.album_id = a.id
                    WHERE LOWER(a.name) LIKE LOWER(CONCAT('%', :query, '%'))
                    GROUP BY a.name, ar.name
                    """,
            countQuery = """
                    SELECT COUNT(DISTINCT a.id)
                    FROM music_library.albums a
                    WHERE LOWER(a.name) LIKE LOWER(CONCAT('%', :query, '%'))
                    """,
            nativeQuery = true
    )
    Page<AlbumListProjection> findAllWithHashes(@Param("query") String query, Pageable pageable);
}
