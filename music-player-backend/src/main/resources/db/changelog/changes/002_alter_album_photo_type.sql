-- liquibase formatted sql
-- changeset Sala Darius:1

ALTER TABLE music_library.albums
    ALTER COLUMN cover_image TYPE TEXT;