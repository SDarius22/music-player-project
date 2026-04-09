-- liquibase formatted sql
-- changeset Sala Darius:2

CREATE TABLE IF NOT EXISTS music_library.playlist_songs
(
    playlist_id BIGINT  NOT NULL,
    song_id     BIGINT  NOT NULL,
    position    INTEGER NOT NULL,
    CONSTRAINT pk_playlist_songs PRIMARY KEY (playlist_id, position),
    CONSTRAINT fk_playlist_songs_playlist FOREIGN KEY (playlist_id) REFERENCES music_library.playlists (id) ON DELETE CASCADE,
    CONSTRAINT fk_playlist_songs_song FOREIGN KEY (song_id) REFERENCES music_library.songs (id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_playlist_songs_song_id
    ON music_library.playlist_songs (song_id);

INSERT INTO music_library.playlist_songs (playlist_id, song_id, position)
SELECT p.id,
       elem.song_id_text::BIGINT,
       elem.ordinality - 1
FROM music_library.playlists p
         CROSS JOIN LATERAL jsonb_array_elements_text(
        COALESCE(NULLIF(TRIM(p.song_ids), ''), '[]')::jsonb
                            ) WITH ORDINALITY AS elem(song_id_text, ordinality)
         JOIN music_library.songs s ON s.id = elem.song_id_text::BIGINT
WHERE elem.song_id_text ~ '^[0-9]+$'
ON CONFLICT (playlist_id, position) DO NOTHING;

