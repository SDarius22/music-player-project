package com.example.musicplayerbackend.controller;

import com.example.musicplayerbackend.domain.ArtistDetailDto;
import com.example.musicplayerbackend.domain.ArtistPageDto;
import com.example.musicplayerbackend.service.ArtistService;
import lombok.RequiredArgsConstructor;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class ArtistController implements ArtistsApi {

    private final ArtistService artistService;

    @Override
    public ResponseEntity<ArtistPageDto> getArtists(String q, Integer page, Integer size, String sort) {
        int safePage = page == null ? 0 : Math.max(page, 0);
        int safeSize = size == null ? 50 : Math.min(Math.max(size, 1), 200);
        return ResponseEntity.ok(artistService.getArtists(q, safePage, safeSize, sort));
    }

    @Override
    public ResponseEntity<ArtistDetailDto> getArtistById(Long artistId) {
        return ResponseEntity.ok(artistService.getArtistById(artistId));
    }

    @Override
    public ResponseEntity<Resource> getArtistCover(Long artistId) {
        byte[] bytes = artistService.getArtistCover(artistId);
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_TYPE, MediaType.IMAGE_JPEG_VALUE)
                .header(HttpHeaders.CACHE_CONTROL, "public, max-age=86400")
                .body(new ByteArrayResource(bytes));
    }
}
