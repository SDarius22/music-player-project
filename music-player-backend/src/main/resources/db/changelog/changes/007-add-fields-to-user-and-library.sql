-- liquibase formatted sql
-- changeset Sala Darius:7

ALTER TABLE music_library.user_library
    ADD COLUMN last_updated TIMESTAMP WITH TIME ZONE,
    ADD COLUMN is_deleted   BOOLEAN DEFAULT FALSE;

ALTER TABLE music_library.users
    ADD COLUMN role     VARCHAR(50) NOT NULL DEFAULT 'USER', -- 'USER' or 'ADMIN'
    ADD COLUMN provider VARCHAR(50) NOT NULL DEFAULT 'LOCAL'; -- 'LOCAL' or 'GOOGLE'