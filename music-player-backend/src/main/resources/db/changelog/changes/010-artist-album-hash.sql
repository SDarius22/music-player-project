-- liquibase formatted sql
-- changeset Sala Darius:10

CREATE EXTENSION IF NOT EXISTS pgcrypto;

ALTER TABLE music_library.artists
    ADD COLUMN IF NOT EXISTS hash VARCHAR(255);

ALTER TABLE music_library.albums
    ADD COLUMN IF NOT EXISTS hash VARCHAR(255);

UPDATE music_library.artists AS target
SET hash = source.hash_value
FROM (SELECT artist.id,
             '[' || STRING_AGG(
                     CASE
                         WHEN get_byte(digest_value.digest_bytes, series.idx) > 127
                             THEN (get_byte(digest_value.digest_bytes, series.idx) - 256)::TEXT
                         ELSE get_byte(digest_value.digest_bytes, series.idx)::TEXT
                         END,
                     ', ' ORDER BY series.idx
                    ) || ']' AS hash_value
      FROM music_library.artists artist
               CROSS JOIN LATERAL (SELECT digest(COALESCE(artist.name, ''), 'sha256') AS digest_bytes) AS digest_value
               CROSS JOIN generate_series(0, 31) AS series(idx)
      WHERE artist.hash IS NULL OR artist.hash = ''
      GROUP BY artist.id, digest_value.digest_bytes) AS source
WHERE target.id = source.id
  AND (target.hash IS NULL OR target.hash = '');

UPDATE music_library.artists
SET hash = encode(digest(COALESCE(name, ''), 'sha256'), 'hex');

UPDATE music_library.albums AS album
SET hash = encode(digest(COALESCE(artist.name, '') || ' - ' || COALESCE(album.name, ''), 'sha256'), 'hex')
    FROM music_library.artists AS artist
WHERE artist.id = album.artist_id;

ALTER TABLE music_library.artists
    ALTER COLUMN hash SET NOT NULL;

ALTER TABLE music_library.albums
    ALTER COLUMN hash SET NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_artists_hash
    ON music_library.artists (hash);

CREATE UNIQUE INDEX IF NOT EXISTS uq_albums_hash
    ON music_library.albums (hash);
