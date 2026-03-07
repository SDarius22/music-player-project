-- liquibase formatted sql
-- changeset Sala Darius:4

CREATE TABLE music_library.user_library
(
    user_id               BIGINT  NOT NULL,
    song_id               INT     NOT NULL,
    liked                 BOOLEAN NOT NULL DEFAULT FALSE,
    play_count            BIGINT  NOT NULL DEFAULT 0,
    last_played           TIMESTAMP WITH TIME ZONE,
    added_at              TIMESTAMP WITH TIME ZONE,
    is_downloaded_locally BOOLEAN          DEFAULT FALSE,
    PRIMARY KEY (user_id, song_id),
    CONSTRAINT fk_library_user FOREIGN KEY (user_id) REFERENCES music_library.users (id) ON DELETE CASCADE,
    CONSTRAINT fk_library_song FOREIGN KEY (song_id) REFERENCES music_library.songs (id) ON DELETE CASCADE
);