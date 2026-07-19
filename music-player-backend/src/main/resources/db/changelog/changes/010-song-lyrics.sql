-- liquibase formatted sql
-- changeset Sala Darius:10

CREATE TABLE music_library.song_lyrics
(
    song_id BIGINT PRIMARY KEY,
    lyrics  TEXT NOT NULL,
    CONSTRAINT fk_song_lyrics_song
        FOREIGN KEY (song_id) REFERENCES music_library.songs (id) ON DELETE CASCADE
);
