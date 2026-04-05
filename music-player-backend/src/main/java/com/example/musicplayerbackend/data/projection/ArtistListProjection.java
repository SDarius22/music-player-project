package com.example.musicplayerbackend.data.projection;

/** Native-query projection for the paginated artist list. */
public interface ArtistListProjection {
    Long getId();
    String getName();
    String getType();        // artist_type AS type
    Long   getOwnerId();
    /** Comma-separated ordered file hashes, or null when the artist has no songs. */
    String getSongFileHashesCsv();
}
