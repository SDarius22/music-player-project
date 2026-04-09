-- liquibase formatted sql
-- changeset Sala Darius:3

CREATE TABLE IF NOT EXISTS music_library.album_artists
(
    album_id  BIGINT NOT NULL,
    artist_id BIGINT NOT NULL,
    CONSTRAINT pk_album_artists PRIMARY KEY (album_id, artist_id),
    CONSTRAINT fk_album_artists_album FOREIGN KEY (album_id) REFERENCES music_library.albums (id) ON DELETE CASCADE,
    CONSTRAINT fk_album_artists_artist FOREIGN KEY (artist_id) REFERENCES music_library.artists (id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_album_artists_artist_id
    ON music_library.album_artists (artist_id);

INSERT INTO music_library.album_artists (album_id, artist_id)
SELECT a.id, a.artist_id
FROM music_library.albums a
WHERE a.artist_id IS NOT NULL
ON CONFLICT DO NOTHING;

WITH canonical AS (SELECT name, MIN(id) AS canonical_id
                   FROM music_library.albums
                   GROUP BY name),
     duplicates AS (SELECT a.id AS old_id, c.canonical_id
                    FROM music_library.albums a
                             JOIN canonical c ON c.name = a.name
                    WHERE a.id <> c.canonical_id)
UPDATE music_library.songs s
SET album_id = d.canonical_id
FROM duplicates d
WHERE s.album_id = d.old_id;

WITH canonical AS (SELECT name, MIN(id) AS canonical_id
                   FROM music_library.albums
                   GROUP BY name),
     duplicates AS (SELECT a.id AS old_id, c.canonical_id
                    FROM music_library.albums a
                             JOIN canonical c ON c.name = a.name
                    WHERE a.id <> c.canonical_id)
INSERT INTO music_library.album_artists (album_id, artist_id)
SELECT d.canonical_id, aa.artist_id
FROM duplicates d
         JOIN music_library.album_artists aa ON aa.album_id = d.old_id
ON CONFLICT DO NOTHING;

WITH canonical AS (SELECT name, MIN(id) AS canonical_id
                   FROM music_library.albums
                   GROUP BY name),
     duplicates AS (SELECT a.id AS old_id, c.canonical_id
                    FROM music_library.albums a
                             JOIN canonical c ON c.name = a.name
                    WHERE a.id <> c.canonical_id)
DELETE
FROM music_library.album_artists aa
    USING duplicates d
WHERE aa.album_id = d.old_id;

WITH canonical AS (SELECT name, MIN(id) AS canonical_id
                   FROM music_library.albums
                   GROUP BY name),
     duplicates AS (SELECT a.id AS old_id, c.canonical_id
                    FROM music_library.albums a
                             JOIN canonical c ON c.name = a.name
                    WHERE a.id <> c.canonical_id)
DELETE
FROM music_library.albums a
    USING duplicates d
WHERE a.id = d.old_id;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

UPDATE music_library.albums
SET hash = encode(digest(COALESCE(name, ''), 'sha256'), 'hex');

ALTER TABLE music_library.albums
    DROP CONSTRAINT IF EXISTS uq_albums_name_artist;

ALTER TABLE music_library.albums
    ADD CONSTRAINT uq_albums_name UNIQUE (name);

