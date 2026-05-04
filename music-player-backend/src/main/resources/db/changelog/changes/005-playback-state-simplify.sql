-- liquibase formatted sql
-- changeset Sala Darius:5

ALTER TABLE music_library.user_playback_state
    DROP COLUMN queue_song_ids;

ALTER TABLE music_library.user_playback_state
    DROP COLUMN current_file_hash;

ALTER TABLE music_library.user_playback_state
    ADD COLUMN position_seconds BIGINT NOT NULL DEFAULT 0;

UPDATE music_library.user_playback_state
SET position_seconds = position_ms / 1000;

ALTER TABLE music_library.user_playback_state
    DROP COLUMN position_ms;
