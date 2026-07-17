package com.example.musicplayerbackend.service;

import com.example.musicplayerbackend.data.SongRepository;
import com.example.musicplayerbackend.data.UserLibraryRepository;
import com.example.musicplayerbackend.domain.Song;
import com.example.musicplayerbackend.domain.SongDto;
import com.example.musicplayerbackend.domain.UserLibrary;
import com.example.musicplayerbackend.mapper.SongMapper;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.function.Function;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Slf4j
@Service
@RequiredArgsConstructor
public class RecommendationService {

  private static final long FORGOTTEN_DAYS = 30;
  private static final long RECENT_HOURS = 48;

  private final UserLibraryRepository userLibraryRepository;
  private final SongRepository songRepository;
  private final SongMapper songMapper;

  @Transactional(readOnly = true)
  public Page<SongDto> getRecommendations(Long userId, Pageable pageable) {
    Instant cutoff = Instant.now().minus(RECENT_HOURS, ChronoUnit.HOURS);
    return withRandomPadding(
        userLibraryRepository.findRecommendationsByUserId(userId, cutoff, pageable),
        userId,
        pageable);
  }

  @Transactional(readOnly = true)
  public Page<SongDto> getForgottenFavourites(Long userId, Pageable pageable) {
    Instant cutoff = Instant.now().minus(FORGOTTEN_DAYS, ChronoUnit.DAYS);
    return withRandomPadding(
        userLibraryRepository.findForgottenByUserId(userId, cutoff, pageable), userId, pageable);
  }

  @Transactional(readOnly = true)
  public Page<SongDto> getQuickDial(Long userId, Pageable pageable) {
    return withRandomPadding(
        userLibraryRepository.findQuickDialByUserId(userId, pageable), userId, pageable);
  }

  @Transactional(readOnly = true)
  public Page<SongDto> getFavourites(Long userId, Pageable pageable) {
    return userLibraryRepository
        .findLikedByUserId(userId, pageable)
        .map(entry -> songMapper.toDto(entry.getSong(), entry));
  }

  @Transactional(readOnly = true)
  public Page<SongDto> getMostPlayed(Long userId, Pageable pageable) {
    return userLibraryRepository
        .findMostPlayedByUserId(userId, pageable)
        .map(entry -> songMapper.toDto(entry.getSong(), entry));
  }

  @Transactional(readOnly = true)
  public Page<SongDto> getRecentlyPlayed(Long userId, Pageable pageable) {
    return userLibraryRepository
        .findRecentlyPlayedByUserId(userId, pageable)
        .map(entry -> songMapper.toDto(entry.getSong(), entry));
  }

  private Page<SongDto> withRandomPadding(
      Page<UserLibrary> matched, Long userId, Pageable pageable) {
    int pageSize = pageable.getPageSize();
    List<SongDto> content = new ArrayList<>(pageSize);
    Set<String> seenHashes = new HashSet<>();

    for (UserLibrary entry : matched.getContent()) {
      Song song = entry.getSong();
      if (song != null && song.getFileHash() != null && seenHashes.add(song.getFileHash())) {
        content.add(songMapper.toDto(song, entry));
      }
    }

    int deficit = pageSize - content.size();
    if (deficit > 0) {
      List<Song> randomSongs = songRepository.findRandomStreamable(PageRequest.of(0, deficit * 3));
      if (!randomSongs.isEmpty()) {
        List<Long> randomIds = randomSongs.stream().map(Song::getId).toList();
        Map<Long, UserLibrary> entriesById =
            userLibraryRepository.findByIdUserIdAndIdSongIdIn(userId, randomIds).stream()
                .filter(ul -> !Boolean.TRUE.equals(ul.getIsDeleted()))
                .collect(Collectors.toMap(ul -> ul.getId().getSongId(), Function.identity()));
        for (Song song : randomSongs) {
          if (content.size() >= pageSize) {
            break;
          }
          if (song.getFileHash() != null && seenHashes.add(song.getFileHash())) {
            content.add(songMapper.toDto(song, entriesById.get(song.getId())));
          }
        }
      }
    }

    long totalElements;
    if (content.size() < pageSize) {
      totalElements = (long) pageable.getPageNumber() * pageSize + content.size();
    } else {
      int totalPages = Math.max(matched.getTotalPages(), pageable.getPageNumber() + 2);
      totalElements = (long) totalPages * pageSize;
    }
    return new PageImpl<>(content, pageable, totalElements);
  }
}
