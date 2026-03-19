package com.example.musicplayerbackend.controller;

import com.example.musicplayerbackend.domain.AlbumDetailDto;
import com.example.musicplayerbackend.domain.AlbumPageDto;
import com.example.musicplayerbackend.service.AlbumService;
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
public class AlbumController implements AlbumsApi {

    private final AlbumService albumService;

    @Override
    public ResponseEntity<AlbumPageDto> getAlbums(String q, Integer page, Integer size, String sort) {
        int safePage = page == null ? 0 : Math.max(page, 0);
        int safeSize = size == null ? 50 : Math.min(Math.max(size, 1), 200);
        return ResponseEntity.ok(albumService.getAlbums(q, safePage, safeSize, sort));
    }

    @Override
    public ResponseEntity<AlbumDetailDto> getAlbumById(Long albumId) {
        return ResponseEntity.ok(albumService.getAlbumById(albumId));
    }

    @Override
    public ResponseEntity<Resource> getAlbumCover(Long albumId) {
        byte[] bytes = albumService.getAlbumCover(albumId);
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_TYPE, MediaType.IMAGE_JPEG_VALUE)
                .header(HttpHeaders.CACHE_CONTROL, "public, max-age=86400")
                .body(new ByteArrayResource(bytes));
    }
}
