-- liquibase formatted sql
-- changeset Sala Darius:6

ALTER TABLE music_library.songs
    ALTER COLUMN owner_id TYPE BIGINT;