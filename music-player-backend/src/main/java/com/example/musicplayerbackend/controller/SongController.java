package com.example.musicplayerbackend.controller;

import com.example.musicplayerbackend.domain.*;
import com.example.musicplayerbackend.service.AlbumService;
import com.example.musicplayerbackend.service.RecommendationService;
import com.example.musicplayerbackend.service.SongService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.lang.Nullable;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import org.springframework.core.io.ByteArrayResource;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;

import java.util.List;
import java.util.Objects;

@Slf4j
@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class SongController implements SongsApi {

    private final SongService songService;
    private final RecommendationService recommendationService;
    private final AlbumService albumService;

    @Override
    public ResponseEntity<SongPageDto> getAllSongs(@Nullable String q, Integer page, Integer size, String sort) {
        int safePage = page == null ? 0 : Math.max(page, 0);
        int safeSize = size == null ? 50 : Math.max(size, 1);
        if (safeSize > 200) {
            safeSize = 200;
        }

        Pageable pageable = PageRequest.of(safePage, safeSize, parseSort(sort));

        User user = getCurrentUser();

        Page<SongDto> result = songService.getSongsVisibleToUser(q, user, pageable);

        return ResponseEntity.ok(new SongPageDto(
                result.getContent(),
                result.getNumber(),
                result.getSize(),
                result.getTotalElements(),
                result.getTotalPages()
        ));
    }

    @Override
    public ResponseEntity<List<SongDto>> getRecommendations() {
        User user = getCurrentUser();
        return ResponseEntity.ok(recommendationService.getRecommendations(user.getId()));
    }

    @Override
    public ResponseEntity<List<SongDto>> getForgottenFavourites() {
        User user = getCurrentUser();
        return ResponseEntity.ok(recommendationService.getForgottenFavourites(user.getId()));
    }

    @Override
    public ResponseEntity<List<SongDto>> getQuickDial() {
        User user = getCurrentUser();
        return ResponseEntity.ok(recommendationService.getQuickDial(user.getId()));
    }

    @Override
    public ResponseEntity<SongDto> getSongById(Long songId) {
        return ResponseEntity.ok(songService.getSongById(songId));
    }

    @Override
    public ResponseEntity<Resource> getSongCover(Long songId) {
        SongDto song = songService.getSongById(songId);
        if (song.getAlbum() == null || song.getAlbum().getId() == null) {
            return ResponseEntity.notFound().build();
        }
        byte[] bytes = albumService.getAlbumCover(song.getAlbum().getId());
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_TYPE, MediaType.IMAGE_JPEG_VALUE)
                .header(HttpHeaders.CACHE_CONTROL, "public, max-age=86400")
                .body(new ByteArrayResource(bytes));
    }

    @Override
    public ResponseEntity<NegotiationResponseDto> negotiateUserUpload(NegotiationRequestDto negotiationRequestDto) {
        User user = getCurrentUser();
        var response = songService.initiateNegotiation(negotiationRequestDto, Objects.requireNonNull(user).getId());
        return ResponseEntity.ok(response);
    }

    @Override
    public ResponseEntity<Void> uploadMissingChunk(Long songId, Integer chunkIndex, MultipartFile chunkData, String contentHash) {
        User user = getCurrentUser();
        log.info("[SONG] Upload missing chunk: songId={}, chunkIndex={}, userId={}", songId, chunkIndex, user.getId());
        try {
            songService.saveMissingChunk(user, songId, chunkIndex, contentHash, chunkData);
            return ResponseEntity.status(HttpStatus.CREATED).build();
        } catch (Exception e) {
            log.error("[SONG] Failed to save chunk: songId={}, chunkIndex={}, userId={}: {}", songId, chunkIndex, user.getId(), e.getMessage());
            return ResponseEntity.badRequest().build();
        }
    }

    @Override
    public ResponseEntity<Void> uploadSong(MultipartFile file, String name, String artistName, String albumName, Integer durationInSeconds, Integer trackNumber, Integer releaseYear, Integer discNumber, String photo, String fileHash) {
        User user = getCurrentUser();
        log.info("[SONG] Admin upload: name='{}', artist='{}', album='{}', userId={}", name, artistName, albumName, user.getId());
        try {
            songService.uploadSong(user, name, artistName, albumName, photo, durationInSeconds, trackNumber, discNumber, releaseYear, file, fileHash);
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
        return (User) Objects.requireNonNull(SecurityContextHolder.getContext().getAuthentication()).getPrincipal();
    }
}