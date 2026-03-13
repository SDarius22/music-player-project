package com.example.musicplayerbackend.controller;

import com.example.musicplayerbackend.domain.ChunkManifestDto;
import com.example.musicplayerbackend.domain.User;
import com.example.musicplayerbackend.service.StreamingService;
import lombok.RequiredArgsConstructor;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Objects;

@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class StreamingController implements StreamApi {

    private final StreamingService streamingService;

    @Override
    public ResponseEntity<Resource> getSongPrefix(Long songId, Integer prefixBytes) {
        Resource resource = streamingService.getSongPrefix(songId, prefixBytes, currentUserId());
        return ResponseEntity.ok()
                .contentType(MediaType.APPLICATION_OCTET_STREAM)
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"song_" + songId + "_prefix\"")
                .body(resource);
    }

    @Override
    public ResponseEntity<Resource> getFullStream(Long songId) {
        Resource resource = streamingService.getFullStream(songId, currentUserId());
        return ResponseEntity.ok()
                .contentType(MediaType.APPLICATION_OCTET_STREAM)
                .header(HttpHeaders.CONTENT_DISPOSITION, "inline; filename=\"song_" + songId + "\"")
                .body(resource);
    }

    @Override
    public ResponseEntity<ChunkManifestDto> getSongManifest(Long songId) {
        return ResponseEntity.ok(streamingService.getSongManifest(songId, currentUserId()));
    }

    @Override
    public ResponseEntity<Resource> getSongChunk(Long songId, Integer chunkIndex) {
        Resource chunk = streamingService.getSongChunk(songId, chunkIndex, currentUserId());
        return ResponseEntity.ok()
                .contentType(MediaType.APPLICATION_OCTET_STREAM)
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"song_" + songId + "_chunk_" + chunkIndex + "\"")
                .body(chunk);
    }

    private Long currentUserId() {
        User user = (User) Objects.requireNonNull(
                SecurityContextHolder.getContext().getAuthentication()
        ).getPrincipal();
        return user.getId();
    }
}