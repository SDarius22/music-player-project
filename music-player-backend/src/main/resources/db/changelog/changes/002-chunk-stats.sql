-- liquibase formatted sql
-- changeset Sala Darius:2

CREATE TABLE music_library.chunk_stats
(
    id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    timestamp      TIMESTAMP WITH TIME ZONE NOT NULL,
    user_id        BIGINT,
    song_id        BIGINT,
    song_name      VARCHAR(255),
    p2p_chunks     INTEGER NOT NULL DEFAULT 0,
    server_chunks  INTEGER NOT NULL DEFAULT 0,
    total_chunks   INTEGER NOT NULL DEFAULT 0,
    p2p_percentage DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    CONSTRAINT fk_chunk_stat_user FOREIGN KEY (user_id) REFERENCES music_library.users (id) ON DELETE SET NULL
);
