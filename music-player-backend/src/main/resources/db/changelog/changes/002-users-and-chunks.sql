-- liquibase formatted sql
-- changeset Sala Darius:2

CREATE TABLE music_library.users
(
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email      VARCHAR(255) NOT NULL UNIQUE,
    created_at TIMESTAMP WITH TIME ZONE
);

CREATE TABLE music_library.verification_codes
(
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email       VARCHAR(255)             NOT NULL,
    code        VARCHAR(255)             NOT NULL,
    expiry_date TIMESTAMP WITH TIME ZONE NOT NULL
);

CREATE TABLE music_library.chunks
(
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    content_hash VARCHAR(64)  NOT NULL UNIQUE,
    size         INT          NOT NULL,
    storage_path VARCHAR(255) NOT NULL
);