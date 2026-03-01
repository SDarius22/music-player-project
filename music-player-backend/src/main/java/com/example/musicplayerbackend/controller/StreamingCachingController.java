package com.example.musicplayerbackend.controller;

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

import java.util.List;

@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class StreamingCachingController implements StreamApi {

    private final StreamingService streamingService;

    @Override
    public ResponseEntity<List<Integer>> getPredictivePrefetchList(String userId) {
        return ResponseEntity.ok(streamingService.getPredictivePrefetchList(userId));
    }

    @Override
    public ResponseEntity<Resource> getSongPrefix(Integer songId, Integer prefixBytes) {
        Resource resource = streamingService.getSongPrefix(songId, prefixBytes);

        // We know from the service implementation that getSongPrefix returns a ByteArrayResource
        int contentLength = ((ByteArrayResource) resource).getByteArray().length;

        return ResponseEntity.ok()
                .contentType(MediaType.APPLICATION_OCTET_STREAM)
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"song_" + songId + "_prefix\"")
                .contentLength(contentLength)
                .body(resource);
    }

    @Override
    public ResponseEntity<Resource> getFullStream(Integer songId) {
        Resource resource = streamingService.getFullStream(songId);

        MediaType mediaType = MediaTypeFactory.getMediaType(resource)
                .orElse(MediaType.APPLICATION_OCTET_STREAM);

        return ResponseEntity.ok()
                .contentType(mediaType)
                .header(HttpHeaders.CONTENT_DISPOSITION, "inline; filename=\"" + resource.getFilename() + "\"")
                .body(resource);
    }
}