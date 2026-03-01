-- liquibase formatted sql
-- changeset Sala Darius:1

CREATE SCHEMA IF NOT EXISTS music_library;

CREATE TABLE music_library.artists
(
    id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(255) NOT NULL
);

CREATE TABLE music_library.albums
(
    id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(255) NOT NULL
);

CREATE TABLE music_library.songs
(
    id                  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name                VARCHAR(255) NOT NULL,
    artist_id           INT,
    album_id            INT,
    photo               VARCHAR(255),
    path                VARCHAR(500) NOT NULL,
    duration_in_seconds INT,
    track_number        INT,
    disc_number         INT,
    release_year        INT,
    last_played         TIMESTAMP WITH TIME ZONE,
    liked_by_user       BOOLEAN      NOT NULL DEFAULT FALSE,
    play_count          INT          NOT NULL DEFAULT 0,
    CONSTRAINT fk_songs_artist_id FOREIGN KEY (artist_id) REFERENCES music_library.artists (id) ON DELETE SET NULL,
    CONSTRAINT fk_songs_album_id FOREIGN KEY (album_id) REFERENCES music_library.albums (id) ON DELETE SET NULL
);