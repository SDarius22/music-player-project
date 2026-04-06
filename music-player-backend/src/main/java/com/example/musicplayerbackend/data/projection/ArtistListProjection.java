package com.example.musicplayerbackend.data.projection;

public interface ArtistListProjection {
    Long getId();

    String getName();

    String getSongFileHashesCsv();
}
