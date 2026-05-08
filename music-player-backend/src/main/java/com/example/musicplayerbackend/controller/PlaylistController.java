package com.example.musicplayerbackend.controller;

import com.example.musicplayerbackend.domain.*;
import com.example.musicplayerbackend.service.PlaylistService;
import lombok.RequiredArgsConstructor;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Objects;

@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class PlaylistController implements PlaylistsApi {

    private final PlaylistService playlistService;

    @Override
    public ResponseEntity<PlaylistPageDto> getPlaylists(String q, String sort, Boolean filterIndestructible, Boolean includeQueue, Integer page, Integer size) {
        User user = currentUser();
        int safePage = page == null ? 0 : Math.max(page, 0);
        int safeSize = size == null ? 50 : Math.min(Math.max(size, 1), 200);
        return ResponseEntity.ok(playlistService.getPlaylists(user.getId(), q, sort, filterIndestructible, includeQueue, safePage, safeSize));
    }

    @Override
    public ResponseEntity<PlaylistDetailDto> getPlaylistByName(String name) {
        User user = currentUser();
        return ResponseEntity.ok(playlistService.getPlaylistByName(user.getId(), name));
    }

    @Override
    public ResponseEntity<PlaylistDetailDto> createPlaylist(CreatePlaylistDto body) {
        User user = currentUser();
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(playlistService.createPlaylist(user, body));
    }

    @Override
    public ResponseEntity<PlaylistDetailDto> getPlaylistById(Long playlistId) {
        User user = currentUser();
        return ResponseEntity.ok(playlistService.getPlaylistById(playlistId, user.getId()));
    }

    @Override
    public ResponseEntity<PlaylistDetailDto> updatePlaylist(Long playlistId, UpdatePlaylistDto body) {
        User user = currentUser();
        return ResponseEntity.ok(playlistService.updatePlaylist(playlistId, user.getId(), body));
    }

    @Override
    public ResponseEntity<Void> deletePlaylist(Long playlistId) {
        User user = currentUser();
        playlistService.deletePlaylist(playlistId, user.getId());
        return ResponseEntity.noContent().build();
    }

    @Override
    public ResponseEntity<Resource> getPlaylistCover(Long playlistId) {
        User user = currentUser();
        byte[] bytes = playlistService.getPlaylistCover(playlistId, user.getId());
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_TYPE, MediaType.IMAGE_JPEG_VALUE)
                .header(HttpHeaders.CACHE_CONTROL, "private, max-age=86400")
                .body(new ByteArrayResource(bytes));
    }

    private User currentUser() {
        return (User) Objects.requireNonNull(
                SecurityContextHolder.getContext().getAuthentication()).getPrincipal();
    }
}
