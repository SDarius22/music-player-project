package com.example.musicplayerbackend.data.projection;

/** Native-query projection for the paginated album list. */
public interface AlbumListProjection {
    Long getId();
    String getName();
    Long   getArtistId();
    String getArtistName();
    /** Comma-separated ordered file hashes, or null when the album has no songs. */
    String getSongFileHashesCsv();
}
