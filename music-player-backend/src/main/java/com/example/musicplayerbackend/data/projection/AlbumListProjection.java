package com.example.musicplayerbackend.data.projection;

public interface AlbumListProjection {
    String getHash();

    String getName();

    String getArtistHash();

    String getArtistName();

    String getSongFileHashesCsv();
}
