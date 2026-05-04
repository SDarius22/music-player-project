-- liquibase formatted sql
-- changeset Sala Darius:4

ALTER TABLE music_library.playlist_songs
    ADD COLUMN song_file_hash VARCHAR(64);

UPDATE music_library.playlist_songs ps
SET song_file_hash = s.file_hash
FROM music_library.songs s
WHERE ps.song_id = s.id;

ALTER TABLE music_library.playlist_songs
    DROP CONSTRAINT IF EXISTS fk_playlist_songs_song;

DROP INDEX IF EXISTS music_library.idx_playlist_songs_song_id;

ALTER TABLE music_library.playlist_songs
    DROP COLUMN song_id;

ALTER TABLE music_library.playlist_songs
    ALTER COLUMN song_file_hash SET NOT NULL;

ALTER TABLE music_library.playlist_songs
    ADD CONSTRAINT fk_playlist_songs_song_file_hash
        FOREIGN KEY (song_file_hash) REFERENCES music_library.songs (file_hash) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_playlist_songs_song_file_hash
    ON music_library.playlist_songs (song_file_hash);