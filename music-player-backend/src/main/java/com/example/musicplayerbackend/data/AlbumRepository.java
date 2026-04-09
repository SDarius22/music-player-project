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
                    SELECT  a.hash as hash,
                            a.name as name,
                            main_artist.hash as artisthash,
                            main_artist.name as artistname,
                            STRING_AGG(s.file_hash, ',' ORDER BY s.disc_number, s.track_number) AS songfilehashescsv
                    FROM music_library.albums a
                    LEFT JOIN LATERAL (
                        SELECT ar.hash, ar.name
                        FROM music_library.album_artists aa
                        JOIN music_library.artists ar ON ar.id = aa.artist_id
                        LEFT JOIN music_library.songs s_artist ON s_artist.album_id = a.id AND s_artist.artist_id = ar.id
                        WHERE aa.album_id = a.id
                        GROUP BY ar.id, ar.hash, ar.name
                        ORDER BY COUNT(s_artist.id) DESC, MIN(s_artist.id) NULLS LAST, ar.id
                        LIMIT 1
                        ) main_artist ON true
                    LEFT JOIN music_library.songs s ON s.album_id = a.id
                    WHERE LOWER(a.name) LIKE LOWER(CONCAT('%', :query, '%'))
                       OR EXISTS (
                           SELECT 1
                           FROM music_library.album_artists aa2
                           JOIN music_library.artists ar2 ON ar2.id = aa2.artist_id
                           WHERE aa2.album_id = a.id
                             AND LOWER(ar2.name) LIKE LOWER(CONCAT('%', :query, '%'))
                       )
                    GROUP BY a.id, a.hash, a.name, main_artist.hash, main_artist.name
                    ORDER BY a.name
                    """,
            countQuery = """
                    SELECT COUNT(DISTINCT a.id)
                    FROM music_library.albums a
                    WHERE LOWER(a.name) LIKE LOWER(CONCAT('%', :query, '%'))
                       OR EXISTS (
                           SELECT 1
                           FROM music_library.album_artists aa
                           JOIN music_library.artists ar ON ar.id = aa.artist_id
                           WHERE aa.album_id = a.id
                             AND LOWER(ar.name) LIKE LOWER(CONCAT('%', :query, '%'))
                       )
                    """,
            nativeQuery = true
    )
    Page<AlbumListProjection> findAllWithHashes(@Param("query") String query, Pageable pageable);
}
