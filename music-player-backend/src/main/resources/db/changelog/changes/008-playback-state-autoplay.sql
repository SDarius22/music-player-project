-- liquibase formatted sql
-- changeset Sala Darius:8

ALTER TABLE music_library.user_playback_state
    ADD COLUMN auto_play BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE music_library.user_playback_state
    ADD COLUMN auto_play_recommendations_page BIGINT NOT NULL DEFAULT 0;

