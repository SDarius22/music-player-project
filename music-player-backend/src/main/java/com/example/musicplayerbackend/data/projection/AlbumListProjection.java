package com.example.musicplayerbackend.data.projection;

/** Native-query projection for the paginated album list. */
public interface AlbumListProjection {
    Long getId();
    String getName();
    String getPhoto();       // cover_image AS photo
    String getType();        // album_type  AS type
    Long   getOwnerId();
    /** Comma-separated ordered file hashes, or null when the album has no songs. */
    String getSongFileHashesCsv();
}
