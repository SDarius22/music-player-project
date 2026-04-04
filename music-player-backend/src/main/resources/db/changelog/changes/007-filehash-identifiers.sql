-- liquibase formatted sql
-- changeset Sala Darius:7

ALTER TABLE music_library.user_playback_state
    DROP CONSTRAINT IF EXISTS user_playback_state_current_song_id_fkey;

ALTER TABLE music_library.user_playback_state
    DROP COLUMN current_song_id;

ALTER TABLE music_library.user_playback_state
    ADD COLUMN current_file_hash VARCHAR(64);

ALTER TABLE music_library.chunk_stats
    DROP COLUMN song_id;

ALTER TABLE music_library.chunk_stats
    ADD COLUMN song_file_hash VARCHAR(64);
