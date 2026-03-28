-- liquibase formatted sql
-- changeset Sala Darius:5

ALTER TABLE music_library.artists
    ADD COLUMN artist_type VARCHAR(50) NOT NULL DEFAULT 'STREAMABLE',
    ADD COLUMN owner_id    BIGINT;

ALTER TABLE music_library.albums
    ADD COLUMN album_type VARCHAR(50) NOT NULL DEFAULT 'STREAMABLE',
    ADD COLUMN owner_id   BIGINT;

ALTER TABLE music_library.playlists
    ADD COLUMN playlist_type VARCHAR(50) NOT NULL DEFAULT 'USER_UPLOAD';
