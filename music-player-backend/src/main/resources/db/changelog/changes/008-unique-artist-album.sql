--liquibase formatted sql
-- changeset Sala Darius:8

ALTER TABLE music_library.artists
    ADD CONSTRAINT uq_artists_name UNIQUE (name);

ALTER TABLE music_library.albums
    ADD CONSTRAINT uq_albums_name_artist UNIQUE (name, artist_id);
