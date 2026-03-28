-- liquibase formatted sql
-- changeset Sala Darius:4

ALTER TABLE music_library.user_playback_state
    ADD COLUMN shuffle BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN repeat  BOOLEAN NOT NULL DEFAULT FALSE;
