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
    Optional<Artist> findByHash(String hash);

    @Query(
            value = """
                    SELECT ar.id,
                           ar.hash,
                           ar.name,
                           STRING_AGG(s.file_hash, ',' ORDER BY s.name)
                               FILTER (WHERE s.file_hash IS NOT NULL AND s.file_hash <> '') AS songfilehashescsv
                    FROM music_library.artists ar
                    LEFT JOIN music_library.songs s  ON s.artist_id = ar.id
                    WHERE LOWER(ar.name) LIKE LOWER(CONCAT('%', :query, '%'))
                    GROUP BY ar.id, ar.hash, LOWER(ar.name)
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
