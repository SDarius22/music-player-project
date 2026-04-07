-- liquibase formatted sql
-- changeset Sala Darius:1

CREATE SCHEMA IF NOT EXISTS music_library;

CREATE TABLE music_library.artists
(
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name        VARCHAR(255) NOT NULL,
    hash        VARCHAR(255) NOT NULL,
    artist_type VARCHAR(50)  NOT NULL DEFAULT 'STREAMABLE',
    owner_id    BIGINT,
    CONSTRAINT uq_artists_name UNIQUE (name)
);

CREATE UNIQUE INDEX uq_artists_hash
    ON music_library.artists (hash);

CREATE TABLE music_library.albums
(
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name        VARCHAR(255) NOT NULL,
    hash        VARCHAR(255) NOT NULL,
    album_type  VARCHAR(50)  NOT NULL DEFAULT 'STREAMABLE',
    owner_id    BIGINT,
    artist_id   BIGINT,
    cover_image TEXT,
    CONSTRAINT fk_album_artist FOREIGN KEY (artist_id) REFERENCES music_library.artists (id),
    CONSTRAINT uq_albums_name_artist UNIQUE (name, artist_id)
);

CREATE UNIQUE INDEX uq_albums_hash
    ON music_library.albums (hash);

CREATE TABLE music_library.users
(
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email      VARCHAR(255) NOT NULL UNIQUE,
    created_at TIMESTAMP WITH TIME ZONE,
    role       VARCHAR(50)  NOT NULL DEFAULT 'USER',
    provider   VARCHAR(50)  NOT NULL DEFAULT 'LOCAL'
);

CREATE TABLE music_library.verification_codes
(
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email       VARCHAR(255)             NOT NULL,
    code        VARCHAR(255)             NOT NULL,
    expiry_date TIMESTAMP WITH TIME ZONE NOT NULL
);

CREATE TABLE music_library.chunks
(
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    content_hash VARCHAR(64)  NOT NULL UNIQUE,
    size         INT          NOT NULL,
    storage_path VARCHAR(255) NOT NULL
);

CREATE TABLE music_library.songs
(
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name                VARCHAR(255) NOT NULL,
    artist_id           BIGINT,
    album_id            BIGINT,
    duration_in_seconds INT,
    track_number        INT,
    disc_number         INT,
    release_year        INT,
    song_type           VARCHAR(50)  NOT NULL DEFAULT 'STREAMABLE',
    owner_id            BIGINT,
    file_hash           VARCHAR(64)  NOT NULL UNIQUE,
    CONSTRAINT fk_songs_artist_id FOREIGN KEY (artist_id) REFERENCES music_library.artists (id) ON DELETE SET NULL,
    CONSTRAINT fk_songs_album_id FOREIGN KEY (album_id) REFERENCES music_library.albums (id) ON DELETE SET NULL
);

CREATE TABLE music_library.song_chunks
(
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    song_id     BIGINT NOT NULL,
    chunk_id    BIGINT NOT NULL,
    order_index INT    NOT NULL,
    CONSTRAINT fk_song_chunks_song FOREIGN KEY (song_id) REFERENCES music_library.songs (id) ON DELETE CASCADE,
    CONSTRAINT fk_song_chunks_chunk FOREIGN KEY (chunk_id) REFERENCES music_library.chunks (id) ON DELETE CASCADE
);

CREATE TABLE music_library.user_library
(
    user_id               BIGINT  NOT NULL,
    song_id               BIGINT  NOT NULL,
    liked                 BOOLEAN NOT NULL DEFAULT FALSE,
    play_count            BIGINT  NOT NULL DEFAULT 0,
    total_play_duration_seconds BIGINT NOT NULL DEFAULT 0,
    last_played           TIMESTAMP WITH TIME ZONE,
    added_at              TIMESTAMP WITH TIME ZONE,
    is_downloaded_locally BOOLEAN          DEFAULT FALSE,
    last_updated          TIMESTAMP WITH TIME ZONE NOT NULL,
    is_deleted            BOOLEAN          NOT NULL DEFAULT FALSE,
    PRIMARY KEY (user_id, song_id),
    CONSTRAINT fk_library_user FOREIGN KEY (user_id) REFERENCES music_library.users (id) ON DELETE CASCADE,
    CONSTRAINT fk_library_song FOREIGN KEY (song_id) REFERENCES music_library.songs (id) ON DELETE CASCADE
);

CREATE TABLE music_library.chunk_stats
(
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    timestamp           TIMESTAMP WITH TIME ZONE NOT NULL,
    user_id             BIGINT,
    song_file_hash      VARCHAR(64),
    song_name           VARCHAR(255),
    local_chunks        INTEGER NOT NULL DEFAULT 0,
    local_cached_chunks INTEGER NOT NULL DEFAULT 0,
    p2p_chunks          INTEGER NOT NULL DEFAULT 0,
    server_chunks       INTEGER NOT NULL DEFAULT 0,
    total_chunks        INTEGER NOT NULL DEFAULT 0,
    p2p_percentage      DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    CONSTRAINT fk_chunk_stat_user FOREIGN KEY (user_id) REFERENCES music_library.users (id) ON DELETE SET NULL
);

CREATE TABLE music_library.playlists
(
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id       BIGINT       NOT NULL REFERENCES music_library.users (id) ON DELETE CASCADE,
    name          VARCHAR(255) NOT NULL,
    playlist_type VARCHAR(50)  NOT NULL DEFAULT 'USER_UPLOAD',
    cover_image   TEXT,
    song_ids      TEXT         NOT NULL DEFAULT '[]',
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_playlists_user_id ON music_library.playlists (user_id);

CREATE TABLE music_library.user_playback_state
(
    user_id           BIGINT PRIMARY KEY REFERENCES music_library.users (id) ON DELETE CASCADE,
    queue_song_ids    TEXT        NOT NULL DEFAULT '[]',
    current_file_hash VARCHAR(64),
    position_ms       BIGINT      NOT NULL DEFAULT 0,
    shuffle           BOOLEAN     NOT NULL DEFAULT FALSE,
    repeat            BOOLEAN     NOT NULL DEFAULT FALSE,
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

