-- liquibase formatted sql
-- changeset Sala Darius:5

ALTER TABLE music_library.artists
    ALTER COLUMN id TYPE BIGINT;

ALTER TABLE music_library.albums
    ALTER COLUMN id TYPE BIGINT;

ALTER TABLE music_library.songs
    ALTER COLUMN id TYPE BIGINT,
    ALTER COLUMN artist_id TYPE BIGINT,
    ALTER COLUMN album_id TYPE BIGINT,
    ALTER COLUMN owner_id TYPE BIGINT;

ALTER TABLE music_library.song_chunks
    ALTER COLUMN song_id TYPE BIGINT;

ALTER TABLE music_library.user_library
    ALTER COLUMN song_id TYPE BIGINT;