-- liquibase formatted sql
-- changeset Sala Darius:3

ALTER TABLE music_library.songs
    ADD COLUMN song_type VARCHAR(50) NOT NULL DEFAULT 'STREAMABLE',
    ADD COLUMN owner_id  INT; -- not adding a foreign key as this can be null, representing songs that are not owned by any user (e.g., streamed songs)

ALTER TABLE music_library.songs
    DROP COLUMN path,
    DROP COLUMN last_played,
    DROP COLUMN liked_by_user,
    DROP COLUMN play_count;


CREATE TABLE music_library.song_chunks
(
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    song_id     INT    NOT NULL,
    chunk_id    BIGINT NOT NULL,
    order_index INT    NOT NULL,
    CONSTRAINT fk_song_chunks_song FOREIGN KEY (song_id) REFERENCES music_library.songs (id) ON DELETE CASCADE,
    CONSTRAINT fk_song_chunks_chunk FOREIGN KEY (chunk_id) REFERENCES music_library.chunks (id) ON DELETE CASCADE
);