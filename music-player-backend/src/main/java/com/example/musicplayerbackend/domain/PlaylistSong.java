package com.example.musicplayerbackend.domain;

import jakarta.persistence.EmbeddedId;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.MapsId;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "playlist_songs")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PlaylistSong {

  @EmbeddedId private PlaylistSongId id;

  @ManyToOne(fetch = FetchType.LAZY)
  @MapsId("playlistId")
  @JoinColumn(name = "playlist_id", nullable = false)
  private Playlist playlist;

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "song_file_hash", referencedColumnName = "file_hash", nullable = false)
  private Song song;
}
