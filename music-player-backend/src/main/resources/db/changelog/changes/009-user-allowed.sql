--liquibase formatted sql

--changeset music-player:009-user-allowed
ALTER TABLE music_library.users
    ADD COLUMN allowed BOOLEAN NOT NULL DEFAULT FALSE;
