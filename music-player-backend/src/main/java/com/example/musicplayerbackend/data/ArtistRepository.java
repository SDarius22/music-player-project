package com.example.musicplayerbackend.data;

import com.example.musicplayerbackend.data.projection.ArtistListProjection;
import com.example.musicplayerbackend.domain.Artist;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface ArtistRepository extends JpaRepository<Artist, Long> {
    Optional<Artist> findByName(String artistName);

    @Query(
        value = """
            SELECT ar.id,
                   ar.name,
                   ar.artist_type    AS type,
                   ar.owner_id       AS ownerid,
                   STRING_AGG(s.file_hash, ',' ORDER BY al.name, s.disc_number, s.track_number)
                       FILTER (WHERE s.file_hash IS NOT NULL AND s.file_hash <> '') AS songfilehashescsv
            FROM music_library.artists ar
            LEFT JOIN music_library.songs s  ON s.artist_id = ar.id
            LEFT JOIN music_library.albums al ON al.id = s.album_id
            WHERE LOWER(ar.name) LIKE LOWER(CONCAT('%', :query, '%'))
            GROUP BY ar.id, ar.name, ar.artist_type, ar.owner_id
            """,
        countQuery = """
            SELECT COUNT(DISTINCT ar.id)
            FROM music_library.artists ar
            WHERE LOWER(ar.name) LIKE LOWER(CONCAT('%', :query, '%'))
            """,
        nativeQuery = true
    )
    Page<ArtistListProjection> findAllWithHashes(@Param("query") String query, Pageable pageable);
}
