package com.example.musicplayerbackend.data;

import com.example.musicplayerbackend.domain.PlaylistSong;
import com.example.musicplayerbackend.domain.PlaylistSongId;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface PlaylistSongRepository extends JpaRepository<PlaylistSong, PlaylistSongId> {

  List<PlaylistSong> findByPlaylist_IdOrderById_PositionAsc(Long playlistId);

  void deleteByPlaylist_Id(Long playlistId);
}
