package com.example.musicplayerbackend.data.projection;

public interface PlaylistListProjection {
  Long getId();

  String getName();

  String getType();

  Long getUserId();

  Boolean getIndestructible();

  String getSongFileHashesCsv();
}
