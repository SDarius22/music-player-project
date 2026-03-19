-- liquibase formatted sql
-- changeset Sala Darius:3

CREATE TABLE music_library.playlists
(
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id     BIGINT       NOT NULL REFERENCES music_library.users (id) ON DELETE CASCADE,
    name        VARCHAR(255) NOT NULL,
    cover_image TEXT,
    song_ids    TEXT         NOT NULL DEFAULT '[]',
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_playlists_user_id ON music_library.playlists (user_id);

CREATE TABLE music_library.user_playback_state
(
    user_id         BIGINT PRIMARY KEY REFERENCES music_library.users (id) ON DELETE CASCADE,
    queue_song_ids  TEXT        NOT NULL DEFAULT '[]',
    current_song_id BIGINT REFERENCES music_library.songs (id) ON DELETE SET NULL,
    position_ms     BIGINT      NOT NULL DEFAULT 0,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
