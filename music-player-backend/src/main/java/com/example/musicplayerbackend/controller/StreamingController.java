package com.example.musicplayerbackend.controller;

import com.example.musicplayerbackend.domain.ChunkManifestDto;
import com.example.musicplayerbackend.domain.User;
import com.example.musicplayerbackend.service.StreamingService;
import java.util.Objects;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@Slf4j
@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class StreamingController implements StreamApi {

  private final StreamingService streamingService;

  @Override
  public ResponseEntity<ChunkManifestDto> getSongManifest(String fileHash) {
    User user = currentUser();
    log.info("[STREAM] Manifest request: fileHash={}, userId={}", fileHash, user.getId());
    return ResponseEntity.ok(streamingService.getSongManifest(fileHash, user));
  }

  @Override
  public ResponseEntity<Resource> getSongChunk(String fileHash, Integer chunkIndex) {
    User user = currentUser();
    log.info(
        "[STREAM] Chunk request (master fallback): fileHash={}, chunkIndex={}, userId={}",
        fileHash,
        chunkIndex,
        user.getId());
    Resource chunk = streamingService.getSongChunk(fileHash, chunkIndex, user);
    return ResponseEntity.ok()
        .contentType(MediaType.APPLICATION_OCTET_STREAM)
        .header(
            HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"chunk_" + chunkIndex + "\"")
        .body(chunk);
  }

  private User currentUser() {
    return (User)
        Objects.requireNonNull(SecurityContextHolder.getContext().getAuthentication())
            .getPrincipal();
  }
}
