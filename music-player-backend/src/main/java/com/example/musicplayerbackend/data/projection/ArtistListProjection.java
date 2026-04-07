package com.example.musicplayerbackend.data.projection;

public interface ArtistListProjection {
    Long getId();

    String getHash();

    String getName();

    String getSongFileHashesCsv();
}
