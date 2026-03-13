-- liquibase formatted sql
-- changeset Sala Darius:1

CREATE SCHEMA IF NOT EXISTS music_library;

CREATE TABLE music_library.artists
(
    id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(255) NOT NULL
);

CREATE TABLE music_library.albums
(
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name        VARCHAR(255) NOT NULL,
    artist_id   BIGINT,
    cover_image TEXT,
    CONSTRAINT fk_album_artist FOREIGN KEY (artist_id) REFERENCES music_library.artists (id)
);

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
    file_hash           VARCHAR(255) NOT NULL,
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
    last_played           TIMESTAMP WITH TIME ZONE,
    added_at              TIMESTAMP WITH TIME ZONE,
    is_downloaded_locally BOOLEAN          DEFAULT FALSE,
    last_updated          TIMESTAMP WITH TIME ZONE,
    is_deleted            BOOLEAN          DEFAULT FALSE,
    PRIMARY KEY (user_id, song_id),
    CONSTRAINT fk_library_user FOREIGN KEY (user_id) REFERENCES music_library.users (id) ON DELETE CASCADE,
    CONSTRAINT fk_library_song FOREIGN KEY (song_id) REFERENCES music_library.songs (id) ON DELETE CASCADE
);
