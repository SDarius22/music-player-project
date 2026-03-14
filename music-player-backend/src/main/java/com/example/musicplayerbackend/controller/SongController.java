package com.example.musicplayerbackend.controller;

import com.example.musicplayerbackend.domain.*;
import com.example.musicplayerbackend.service.SongService;
import lombok.RequiredArgsConstructor;
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

import java.util.Objects;

@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class SongController implements SongsApi {

    private final SongService songService;

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
    public ResponseEntity<SongDto> getSongById(Long songId) {
        return ResponseEntity.ok(songService.getSongById(songId));
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
        try {
            songService.saveMissingChunk(user, songId, chunkIndex, contentHash, chunkData);
            return ResponseEntity.status(HttpStatus.CREATED).build();
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().build();
        }
    }

    @Override
    public ResponseEntity<Void> uploadSong(MultipartFile file, String name, String artistName, String albumName, Integer durationInSeconds, Integer trackNumber, Integer releaseYear, Integer discNumber, String photo, String fileHash) {
        User user = getCurrentUser();
        try {
            songService.uploadSong(user, name, artistName, albumName, photo, durationInSeconds, trackNumber, discNumber, releaseYear, file, fileHash);
            return ResponseEntity.status(HttpStatus.CREATED).build();
        } catch (Exception e) {
            e.printStackTrace();
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