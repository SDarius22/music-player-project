package com.example.musicplayerbackend.data.projection;

/** Native-query projection for the paginated playlist list. */
public interface PlaylistListProjection {
    Long getId();
    String getName();
    String getType();       // playlist_type AS type
    Long getUserId();       // user_id AS userid
    Boolean getHasCover();  // computed: cover_image IS NOT NULL AND TRIM(cover_image) <> ''
    /** Comma-separated ordered file hashes, or null when the playlist has no songs. */
    String getSongFileHashesCsv();
}
