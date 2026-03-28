package com.example.musicplayerbackend.service;

import com.example.musicplayerbackend.data.PlaylistRepository;
import com.example.musicplayerbackend.data.SongRepository;
import com.example.musicplayerbackend.domain.*;
import com.example.musicplayerbackend.mapper.SongMapper;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

@Service
@RequiredArgsConstructor
public class PlaylistService {

    private final PlaylistRepository playlistRepository;
    private final SongRepository songRepository;
    private final SongMapper songMapper;
    private final ObjectMapper objectMapper;

    public PlaylistPageDto getPlaylists(Long userId, int page, int size) {
        Page<Playlist> result = playlistRepository.findAllByUserId(userId,
                PageRequest.of(page, size));
        List<PlaylistDto> content = result.getContent().stream().map(this::toDto).toList();
        return new PlaylistPageDto(content, result.getNumber(), result.getSize(),
                result.getTotalElements(), result.getTotalPages());
    }

    @Transactional
    public PlaylistDetailDto createPlaylist(User user, CreatePlaylistDto req) {
        List<Long> songIds = req.getSongIds() == null ? List.of() : req.getSongIds();
        Playlist playlist = Playlist.builder()
                .user(user)
                .name(req.getName())
                .playlistType(ContentType.USER_UPLOAD)
                .coverImage(req.getCoverImage())
                .songIdsJson(toJson(songIds))
                .build();
        return toDetailDto(playlistRepository.save(playlist));
    }

    public PlaylistDetailDto getPlaylistById(Long playlistId, Long userId) {
        Playlist playlist = findAndAuthorize(playlistId, userId);
        return toDetailDto(playlist);
    }

    @Transactional
    public PlaylistDetailDto updatePlaylist(Long playlistId, Long userId, UpdatePlaylistDto req) {
        Playlist playlist = findAndAuthorize(playlistId, userId);
        if (req.getName() != null) {
            playlist.setName(req.getName());
        }
        if (req.getSongIds() != null) {
            playlist.setSongIdsJson(toJson(req.getSongIds()));
        }
        // coverImage: null = no change; empty string = remove cover; non-empty = set new cover
        if (req.getCoverImage() != null) {
            playlist.setCoverImage(req.getCoverImage().isBlank() ? null : req.getCoverImage());
        }
        playlist.setUpdatedAt(Instant.now());
        return toDetailDto(playlistRepository.save(playlist));
    }

    @Transactional
    public void deletePlaylist(Long playlistId, Long userId) {
        Playlist playlist = findAndAuthorize(playlistId, userId);
        playlistRepository.delete(playlist);
    }

    public byte[] getPlaylistCover(Long playlistId, Long userId) {
        Playlist playlist = findAndAuthorize(playlistId, userId);
        return AlbumService.decodeCoverImage(playlist.getCoverImage());
    }

    // ── helpers ──────────────────────────────────────────────────────────────

    private Playlist findAndAuthorize(Long playlistId, Long userId) {
        Playlist playlist = playlistRepository.findById(playlistId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Playlist not found"));
        if (!playlist.getUser().getId().equals(userId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Access denied");
        }
        return playlist;
    }

    private PlaylistDto toDto(Playlist p) {
        List<Long> ids = fromJson(p.getSongIdsJson());
        PlaylistDto dto = new PlaylistDto();
        dto.setId(p.getId());
        dto.setName(p.getName());
        dto.setType(p.getPlaylistType() != null ? PlaylistDto.TypeEnum.fromValue(p.getPlaylistType().name()) : null);
        dto.setUserId(p.getUser().getId());
        dto.setSongIds(ids);
        dto.setHasCover(p.getCoverImage() != null && !p.getCoverImage().isBlank());
        return dto;
    }

    private PlaylistDetailDto toDetailDto(Playlist p) {
        List<Long> ids = fromJson(p.getSongIdsJson());
        List<SongDto> songs = ids.isEmpty() ? List.of() :
                songRepository.findAllById(ids).stream().map(songMapper::toDto).toList();

        PlaylistDetailDto dto = new PlaylistDetailDto();
        dto.setId(p.getId());
        dto.setName(p.getName());
        dto.setType(p.getPlaylistType() != null ? PlaylistDetailDto.TypeEnum.fromValue(p.getPlaylistType().name()) : null);
        dto.setUserId(p.getUser().getId());
        dto.setSongs(songs);
        dto.setHasCover(p.getCoverImage() != null && !p.getCoverImage().isBlank());
        return dto;
    }

    private String toJson(List<Long> ids) {
        try {
            return objectMapper.writeValueAsString(ids == null ? new ArrayList<>() : ids);
        } catch (JsonProcessingException e) {
            return "[]";
        }
    }

    private List<Long> fromJson(String json) {
        if (json == null || json.isBlank()) return List.of();
        try {
            return objectMapper.readValue(json, new TypeReference<>() {});
        } catch (JsonProcessingException e) {
            return List.of();
        }
    }
}
