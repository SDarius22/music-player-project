package com.example.musicplayerbackend.controller;

import com.example.musicplayerbackend.domain.ChunkManifestDto;
import com.example.musicplayerbackend.service.StreamingService;
import lombok.RequiredArgsConstructor;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.MediaTypeFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class StreamingController implements StreamApi {

    private final StreamingService streamingService;

    @Override
    public ResponseEntity<Resource> getSongPrefix(Long songId, Integer prefixBytes) {
        Resource resource = streamingService.getSongPrefix(songId, prefixBytes);

        int contentLength = ((ByteArrayResource) resource).getByteArray().length;

        return ResponseEntity.ok()
                .contentType(MediaType.APPLICATION_OCTET_STREAM)
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"song_" + songId + "_prefix\"")
                .contentLength(contentLength)
                .body(resource);
    }

    @Override
    public ResponseEntity<Resource> getFullStream(Long songId) {
        Resource resource = streamingService.getFullStream(songId);

        MediaType mediaType = MediaTypeFactory.getMediaType(resource)
                .orElse(MediaType.APPLICATION_OCTET_STREAM);

        return ResponseEntity.ok()
                .contentType(mediaType)
                .header(HttpHeaders.CONTENT_DISPOSITION, "inline; filename=\"" + resource.getFilename() + "\"")
                .body(resource);
    }

    @Override
    public ResponseEntity<ChunkManifestDto> getSongManifest(Long songId) {
        System.out.println("[MASTER SERVER] Received request for manifest of song ID: " + songId);
        return ResponseEntity.ok(streamingService.getSongManifest(songId));
    }

    @Override
    public ResponseEntity<Resource> getSongChunk(Long songId, Integer chunkIndex) {
        System.out.println("[MASTER SERVER] Received request for chunk " + chunkIndex + " of song ID: " + songId);
        Resource chunk = streamingService.getSongChunk(songId, chunkIndex);

        return ResponseEntity.ok()
                .contentType(MediaType.APPLICATION_OCTET_STREAM)
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"song_" + songId + "_chunk_" + chunkIndex + "\"")
                .body(chunk);
    }
}