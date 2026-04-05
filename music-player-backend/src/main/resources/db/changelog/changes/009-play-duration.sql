--liquibase formatted sql
-- changeset Sala Darius:9

ALTER TABLE music_library.user_library
    ADD COLUMN total_play_duration_seconds BIGINT NOT NULL DEFAULT 0;
