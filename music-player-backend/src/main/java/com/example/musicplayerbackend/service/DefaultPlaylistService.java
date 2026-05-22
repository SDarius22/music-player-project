package com.example.musicplayerbackend.service;

import com.example.musicplayerbackend.data.PlaylistRepository;
import com.example.musicplayerbackend.data.PlaylistSongRepository;
import com.example.musicplayerbackend.data.SongRepository;
import com.example.musicplayerbackend.data.UserLibraryRepository;
import com.example.musicplayerbackend.domain.ContentType;
import com.example.musicplayerbackend.domain.Playlist;
import com.example.musicplayerbackend.domain.PlaylistSong;
import com.example.musicplayerbackend.domain.PlaylistSongId;
import com.example.musicplayerbackend.domain.Song;
import com.example.musicplayerbackend.domain.User;
import com.example.musicplayerbackend.domain.UserLibrary;
import java.util.ArrayList;
import java.util.List;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Slf4j
@Service
@RequiredArgsConstructor
public class DefaultPlaylistService {

  static final String QUEUE = "Queue";
  static final String FAVOURITES = "Favourites";
  static final String MOST_PLAYED = "Most Played";
  static final String RECENTLY_PLAYED = "Recently Played";

  private static final int QUEUE_RANDOM_SIZE = 25;
  private static final int LIBRARY_SNAPSHOT_SIZE = 50;

  private final PlaylistRepository playlistRepository;
  private final PlaylistSongRepository playlistSongRepository;
  private final SongRepository songRepository;
  private final UserLibraryRepository userLibraryRepository;

  @Transactional
  public void provisionDefaultPlaylists(User user) {
    Long userId = user.getId();
    if (userId == null) {
      return;
    }

    if (!playlistRepository.existsByUser_IdAndName(userId, QUEUE)) {
      createPlaylist(
          user, QUEUE, songRepository.findRandomStreamable(PageRequest.of(0, QUEUE_RANDOM_SIZE)));
    }
    if (!playlistRepository.existsByUser_IdAndName(userId, FAVOURITES)) {
      createPlaylist(
          user,
          FAVOURITES,
          songsFromLibrary(
              userLibraryRepository
                  .findLikedByUserId(userId, PageRequest.of(0, LIBRARY_SNAPSHOT_SIZE))
                  .getContent()));
    }
    if (!playlistRepository.existsByUser_IdAndName(userId, MOST_PLAYED)) {
      createPlaylist(
          user,
          MOST_PLAYED,
          songsFromLibrary(
              userLibraryRepository
                  .findMostPlayedByUserId(userId, PageRequest.of(0, LIBRARY_SNAPSHOT_SIZE))
                  .getContent()));
    }
    if (!playlistRepository.existsByUser_IdAndName(userId, RECENTLY_PLAYED)) {
      createPlaylist(
          user,
          RECENTLY_PLAYED,
          songsFromLibrary(
              userLibraryRepository
                  .findRecentlyPlayedByUserId(userId, PageRequest.of(0, LIBRARY_SNAPSHOT_SIZE))
                  .getContent()));
    }
  }

  private void createPlaylist(User user, String name, List<Song> songs) {
    Playlist playlist =
        playlistRepository.save(
            Playlist.builder()
                .user(user)
                .name(name)
                .playlistType(ContentType.USER_UPLOAD)
                .indestructible(true)
                .build());

    if (songs == null || songs.isEmpty()) {
      log.info("[PROVISION] Created empty default playlist '{}' for userId={}", name, user.getId());
      return;
    }

    List<PlaylistSong> entries = new ArrayList<>(songs.size());
    int position = 0;
    for (Song song : songs) {
      if (song == null || song.getId() == null) {
        continue;
      }
      entries.add(
          PlaylistSong.builder()
              .id(new PlaylistSongId(playlist.getId(), position++))
              .playlist(playlist)
              .song(song)
              .build());
    }
    if (!entries.isEmpty()) {
      playlistSongRepository.saveAll(entries);
    }
    log.info(
        "[PROVISION] Created default playlist '{}' with {} songs for userId={}",
        name,
        entries.size(),
        user.getId());
  }

  @Transactional
  public void syncAfterLibraryPatch(
      Long userId,
      boolean likedChanged,
      boolean playCountChanged,
      boolean lastPlayedChanged,
      boolean entryLikedNow) {
    if (userId == null) {
      return;
    }

    if (likedChanged || (playCountChanged && entryLikedNow)) {
      rebuildPlaylist(
          userId,
          FAVOURITES,
          songsFromLibrary(
              userLibraryRepository
                  .findLikedByUserId(userId, PageRequest.of(0, LIBRARY_SNAPSHOT_SIZE))
                  .getContent()));
    }
    if (playCountChanged) {
      rebuildPlaylist(
          userId,
          MOST_PLAYED,
          songsFromLibrary(
              userLibraryRepository
                  .findMostPlayedByUserId(userId, PageRequest.of(0, LIBRARY_SNAPSHOT_SIZE))
                  .getContent()));
    }
    if (lastPlayedChanged) {
      rebuildPlaylist(
          userId,
          RECENTLY_PLAYED,
          songsFromLibrary(
              userLibraryRepository
                  .findRecentlyPlayedByUserId(userId, PageRequest.of(0, LIBRARY_SNAPSHOT_SIZE))
                  .getContent()));
    }
  }

  private void rebuildPlaylist(Long userId, String name, List<Song> songs) {
    Playlist playlist = playlistRepository.findByUser_IdAndName(userId, name).orElse(null);
    if (playlist == null) {
      return;
    }

    playlistSongRepository.deleteByPlaylist_Id(playlist.getId());
    playlistSongRepository.flush();

    List<PlaylistSong> entries = new ArrayList<>(songs.size());
    int position = 0;
    for (Song song : songs) {
      if (song == null || song.getId() == null) {
        continue;
      }
      entries.add(
          PlaylistSong.builder()
              .id(new PlaylistSongId(playlist.getId(), position++))
              .playlist(playlist)
              .song(song)
              .build());
    }
    if (!entries.isEmpty()) {
      playlistSongRepository.saveAll(entries);
    }
    log.info(
        "[SYNC] Rebuilt default playlist '{}' for userId={} ({} songs)",
        name,
        userId,
        entries.size());
  }

  private List<Song> songsFromLibrary(List<UserLibrary> entries) {
    List<Song> songs = new ArrayList<>(entries.size());
    for (UserLibrary entry : entries) {
      Song song = entry.getSong();
      if (song != null) {
        songs.add(song);
      }
    }
    return songs;
  }
}
