package com.example.musicplayerbackend.controller;

import com.example.musicplayerbackend.domain.AlbumExpandedDto;
import com.example.musicplayerbackend.domain.AlbumPageDto;
import com.example.musicplayerbackend.domain.SongPageDto;
import com.example.musicplayerbackend.domain.User;
import com.example.musicplayerbackend.service.AlbumService;
import java.util.Objects;
import lombok.RequiredArgsConstructor;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class AlbumController implements AlbumsApi {

  private final AlbumService albumService;

  @Override
  public ResponseEntity<AlbumPageDto> getAlbums(
      String query, Integer page, Integer size, String sort) {
    return ResponseEntity.ok(albumService.getAlbums(query, page, size, sort));
  }

  @Override
  public ResponseEntity<AlbumExpandedDto> getAlbumByHash(String albumHash) {
    return ResponseEntity.ok(albumService.getAlbumByHash(albumHash, currentUserId()));
  }

  private Long currentUserId() {
    User user =
        (User)
            Objects.requireNonNull(SecurityContextHolder.getContext().getAuthentication())
                .getPrincipal();
    return user.getId();
  }

  @Override
  public ResponseEntity<Resource> getAlbumCover(String albumHash) {
    byte[] bytes = albumService.getAlbumCover(albumHash);
    return ResponseEntity.ok()
        .header(HttpHeaders.CONTENT_TYPE, MediaType.IMAGE_JPEG_VALUE)
        .header(HttpHeaders.CACHE_CONTROL, "public, max-age=86400")
        .body(new ByteArrayResource(bytes));
  }

  @Override
  public ResponseEntity<SongPageDto> getAlbumSongs(String albumHash, Integer page, Integer size) {
    return ResponseEntity.ok(albumService.getAlbumSongs(albumHash, currentUserId(), page, size));
  }
}
