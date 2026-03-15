package com.example.musicplayerbackend.controller;

import com.example.musicplayerbackend.domain.ChunkManifestDto;
import com.example.musicplayerbackend.domain.User;
import com.example.musicplayerbackend.service.StreamingService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Objects;

@Slf4j
@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class StreamingController implements StreamApi {

    private final StreamingService streamingService;

    @Override
    public ResponseEntity<Resource> getSongPrefix(Long songId, Integer prefixBytes) {
        long userId = currentUserId();
        log.info("[STREAM] Prefix request: songId={}, prefixBytes={}, userId={}", songId, prefixBytes, userId);
        Resource resource = streamingService.getSongPrefix(songId, prefixBytes, userId);
        return ResponseEntity.ok()
                .contentType(MediaType.APPLICATION_OCTET_STREAM)
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"song_" + songId + "_prefix\"")
                .body(resource);
    }

    @Override
    public ResponseEntity<Resource> getFullStream(Long songId) {
        long userId = currentUserId();
        log.info("[STREAM] Full stream request (master fallback): songId={}, userId={}", songId, userId);
        Resource resource = streamingService.getFullStream(songId, userId);
        return ResponseEntity.ok()
                .contentType(MediaType.APPLICATION_OCTET_STREAM)
                .header(HttpHeaders.CONTENT_DISPOSITION, "inline; filename=\"song_" + songId + "\"")
                .body(resource);
    }

    @Override
    public ResponseEntity<ChunkManifestDto> getSongManifest(Long songId) {
        long userId = currentUserId();
        log.info("[STREAM] Manifest request: songId={}, userId={}", songId, userId);
        return ResponseEntity.ok(streamingService.getSongManifest(songId, userId));
    }

    @Override
    public ResponseEntity<Resource> getSongChunk(Long songId, Integer chunkIndex) {
        long userId = currentUserId();
        log.info("[STREAM] Chunk request (master fallback): songId={}, chunkIndex={}, userId={}", songId, chunkIndex, userId);
        Resource chunk = streamingService.getSongChunk(songId, chunkIndex, userId);
        return ResponseEntity.ok()
                .contentType(MediaType.APPLICATION_OCTET_STREAM)
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"song_" + songId + "_chunk_" + chunkIndex + "\"")
                .body(chunk);
    }

    private long currentUserId() {
        User user = (User) Objects.requireNonNull(
                SecurityContextHolder.getContext().getAuthentication()
        ).getPrincipal();
        return user.getId();
    }
}