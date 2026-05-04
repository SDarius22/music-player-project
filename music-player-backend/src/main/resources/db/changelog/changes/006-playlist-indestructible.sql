-- liquibase formatted sql
-- changeset Sala Darius:6

ALTER TABLE music_library.playlists
    ADD COLUMN indestructible BOOLEAN NOT NULL DEFAULT FALSE;
