package com.example.musicplayerbackend.controller;

import com.example.musicplayerbackend.domain.ArtistExpandedDto;
import com.example.musicplayerbackend.domain.ArtistPageDto;
import com.example.musicplayerbackend.domain.SongPageDto;
import com.example.musicplayerbackend.domain.User;
import com.example.musicplayerbackend.service.ArtistService;
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
public class ArtistController implements ArtistsApi {

  private final ArtistService artistService;

  @Override
  public ResponseEntity<ArtistPageDto> getArtists(
      String q, Integer page, Integer size, String sort) {
    return ResponseEntity.ok(artistService.getArtists(q, page, size, sort));
  }

  @Override
  public ResponseEntity<ArtistExpandedDto> getArtistByHash(String artistHash) {
    return ResponseEntity.ok(artistService.getArtistByHash(artistHash, currentUserId()));
  }

  private Long currentUserId() {
    User user =
        (User)
            Objects.requireNonNull(SecurityContextHolder.getContext().getAuthentication())
                .getPrincipal();
    return user.getId();
  }

  @Override
  public ResponseEntity<Resource> getArtistCover(String artistHash) {
    byte[] bytes = artistService.getArtistCover(artistHash, currentUserId());
    return ResponseEntity.ok()
        .header(HttpHeaders.CONTENT_TYPE, MediaType.IMAGE_JPEG_VALUE)
        .header(HttpHeaders.CACHE_CONTROL, "public, max-age=86400")
        .body(new ByteArrayResource(bytes));
  }

  @Override
  public ResponseEntity<SongPageDto> getArtistSongs(String artistHash, Integer page, Integer size) {
    return ResponseEntity.ok(artistService.getArtistSongs(artistHash, currentUserId(), page, size));
  }
}
