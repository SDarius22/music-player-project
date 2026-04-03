-- liquibase formatted sql
-- changeset Sala Darius:6

ALTER TABLE music_library.chunk_stats
    ADD COLUMN local_chunks        INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN local_cached_chunks INTEGER NOT NULL DEFAULT 0;
