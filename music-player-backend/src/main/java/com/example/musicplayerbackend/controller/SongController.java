package com.example.musicplayerbackend.controller;

import com.example.musicplayerbackend.domain.NegotiationRequestDto;
import com.example.musicplayerbackend.domain.NegotiationResponseDto;
import com.example.musicplayerbackend.domain.SongDto;
import com.example.musicplayerbackend.domain.SongPageDto;
import com.example.musicplayerbackend.domain.UpdateUserSongDto;
import com.example.musicplayerbackend.domain.User;
import com.example.musicplayerbackend.service.RecommendationService;
import com.example.musicplayerbackend.service.SongService;
import java.util.Objects;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.jspecify.annotations.Nullable;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.core.io.Resource;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

@Slf4j
@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class SongController implements SongsApi {

  private final SongService songService;
  private final RecommendationService recommendationService;

  @Override
  public ResponseEntity<SongPageDto> getAllSongs(@Nullable String q, Integer page, Integer size,
      String sort, @Nullable String filterAlbumHash, @Nullable String filterArtistHash,
      @Nullable Long filterPlaylistId) {
    int safePage = page == null ? 0 : Math.max(page, 0);
    int safeSize = size == null ? 50 : Math.max(size, 1);
    if (safeSize > 200) {
      safeSize = 200;
    }

    Pageable pageable = PageRequest.of(safePage, safeSize, parseSort(sort));

    User user = getCurrentUser();

    Page<SongDto> result = songService.getSongsVisibleToUser(q, filterAlbumHash, filterArtistHash,
        filterPlaylistId, user, pageable);

    return ResponseEntity.ok(new SongPageDto(
        result.getContent(),
        result.getNumber(),
        result.getSize(),
        result.getTotalElements(),
        result.getTotalPages()
    ));
  }

  @Override
  public ResponseEntity<SongPageDto> getRecommendations(Integer page, Integer size) {
    return ResponseEntity.ok(toPageDto(
        recommendationService.getRecommendations(getCurrentUser().getId(),
            libraryPageable(page, size))));
  }

  @Override
  public ResponseEntity<SongPageDto> getForgottenFavourites(Integer page, Integer size) {
    return ResponseEntity.ok(toPageDto(
        recommendationService.getForgottenFavourites(getCurrentUser().getId(),
            libraryPageable(page, size))));
  }

  @Override
  public ResponseEntity<SongPageDto> getQuickDial(Integer page, Integer size) {
    return ResponseEntity.ok(toPageDto(
        recommendationService.getQuickDial(getCurrentUser().getId(), libraryPageable(page, size))));
  }

  @Override
  public ResponseEntity<SongPageDto> getFavourites(Integer page, Integer size) {
    return ResponseEntity.ok(toPageDto(
        recommendationService.getFavourites(getCurrentUser().getId(),
            libraryPageable(page, size))));
  }

  @Override
  public ResponseEntity<SongPageDto> getMostPlayed(Integer page, Integer size) {
    return ResponseEntity.ok(toPageDto(
        recommendationService.getMostPlayed(getCurrentUser().getId(),
            libraryPageable(page, size))));
  }

  @Override
  public ResponseEntity<SongPageDto> getRecentlyPlayed(Integer page, Integer size) {
    return ResponseEntity.ok(toPageDto(
        recommendationService.getRecentlyPlayed(getCurrentUser().getId(),
            libraryPageable(page, size))));
  }

  private Pageable libraryPageable(Integer page, Integer size) {
    int safePage = page == null ? 0 : Math.max(page, 0);
    int safeSize = size == null ? 50 : Math.max(size, 1);
    if (safeSize > 200) {
      safeSize = 200;
    }
    return PageRequest.of(safePage, safeSize);
  }

  private SongPageDto toPageDto(Page<SongDto> page) {
    return new SongPageDto(
        page.getContent(),
        page.getNumber(),
        page.getSize(),
        page.getTotalElements(),
        page.getTotalPages()
    );
  }

  @Override
  public ResponseEntity<SongDto> getSongById(String fileHash) {
    return ResponseEntity.ok(songService.getSongByFileHash(fileHash, getCurrentUser().getId()));
  }

  @Override
  public ResponseEntity<SongDto> updateUserSongLibrary(String fileHash, UpdateUserSongDto body) {
    return ResponseEntity.ok(
        songService.updateUserSongLibrary(fileHash, getCurrentUser().getId(), body));
  }

  @Override
  public ResponseEntity<Resource> getSongCover(String fileHash) {
    byte[] bytes = songService.getSongCover(fileHash);
    return ResponseEntity.ok()
        .header(HttpHeaders.CONTENT_TYPE, MediaType.IMAGE_JPEG_VALUE)
        .header(HttpHeaders.CACHE_CONTROL, "public, max-age=86400")
        .body(new ByteArrayResource(bytes));
  }

  @Override
  public ResponseEntity<NegotiationResponseDto> negotiateUserUpload(
      NegotiationRequestDto negotiationRequestDto) {
    User user = getCurrentUser();
    try {
      var response = songService.initiateNegotiation(negotiationRequestDto,
          Objects.requireNonNull(user).getId());
      return ResponseEntity.ok(response);
    } catch (Exception e) {
      log.error("[SONG] Negotiation failed for userId={}: {}", user.getId(), e.getMessage());
      return ResponseEntity.badRequest().build();
    }

  }

  @Override
  public ResponseEntity<Void> uploadMissingChunk(String fileHash, Integer chunkIndex,
      MultipartFile chunkData, String contentHash) {
    User user = getCurrentUser();
    log.info("[SONG] Upload missing chunk: fileHash={}, chunkIndex={}, userId={}", fileHash,
        chunkIndex, user.getId());
    try {
      songService.saveMissingChunk(user, fileHash, chunkIndex, contentHash, chunkData);
      return ResponseEntity.status(HttpStatus.CREATED).build();
    } catch (Exception e) {
      log.error("[SONG] Failed to save chunk: fileHash={}, chunkIndex={}, userId={}: {}", fileHash,
          chunkIndex, user.getId(), e.getMessage());
      return ResponseEntity.badRequest().build();
    }
  }

  @Override
  public ResponseEntity<Void> uploadSong(MultipartFile file, String name, String artistName,
      String albumName, Integer durationInSeconds, Integer trackNumber, Integer releaseYear,
      Integer discNumber, String photo, String fileHash) {
    User user = getCurrentUser();
    log.info("[SONG] Admin upload: name='{}', artist='{}', album='{}', userId={}", name, artistName,
        albumName, user.getId());
    try {
      songService.uploadSong(user, name, artistName, albumName, photo, durationInSeconds,
          trackNumber, discNumber, releaseYear, file, fileHash);
      return ResponseEntity.status(HttpStatus.CREATED).build();
    } catch (Exception e) {
      log.error("[SONG] Upload failed for '{}': {}", name, e.getMessage());
      return ResponseEntity.badRequest().build();
    }
  }

  private Sort parseSort(String sort) {
    if (sort == null || sort.isBlank()) {
      return Sort.by(Sort.Order.asc("name"));
    }
    String[] parts = sort.split(",", 2);
    String property = parts[0].trim();
    String dir = parts.length > 1 ? parts[1].trim().toLowerCase() : "asc";

    property = switch (property) {
      case "name" -> "name";
      case "year" -> "releaseYear";
      case "durationInSeconds" -> "durationInSeconds";
      case "trackNumber" -> "trackNumber";
      case "discNumber" -> "discNumber";
      default -> "name";
    };

    return "desc".equals(dir)
        ? Sort.by(Sort.Order.desc(property))
        : Sort.by(Sort.Order.asc(property));
  }

  User getCurrentUser() {
    return (User) Objects.requireNonNull(SecurityContextHolder.getContext().getAuthentication())
        .getPrincipal();
  }
}