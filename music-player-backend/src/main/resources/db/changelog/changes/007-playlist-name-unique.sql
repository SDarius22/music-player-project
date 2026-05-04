-- liquibase formatted sql
-- changeset Sala Darius:7

ALTER TABLE music_library.playlists
    ADD CONSTRAINT uq_playlists_user_id_name UNIQUE (user_id, name);
