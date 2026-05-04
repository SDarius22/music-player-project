package com.example.musicplayerbackend.service;

import com.example.musicplayerbackend.data.PlaylistRepository;
import com.example.musicplayerbackend.data.PlaylistSongRepository;
import com.example.musicplayerbackend.data.SongRepository;
import com.example.musicplayerbackend.data.projection.PlaylistListProjection;
import com.example.musicplayerbackend.domain.*;
import com.example.musicplayerbackend.helpers.CoverDecoder;
import com.example.musicplayerbackend.mapper.PlaylistMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.Instant;
import java.util.*;
import java.util.function.Function;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class PlaylistService {

    private final PlaylistRepository playlistRepository;
    private final PlaylistSongRepository playlistSongRepository;
    private final SongRepository songRepository;
    private final PlaylistMapper playlistMapper;
    private final SongEnrichmentService songEnrichmentService;

    public PlaylistPageDto getPlaylists(Long userId, int page, int size) {
        Page<PlaylistListProjection> result = playlistRepository.findAllWithHashes(userId, PageRequest.of(page, size));

        List<PlaylistDto> content = result.getContent().stream()
                .map(playlistMapper::toDto)
                .toList();

        return new PlaylistPageDto(
                content,
                result.getNumber(),
                result.getSize(),
                result.getTotalElements(),
                result.getTotalPages()
        );
    }

    @Transactional
    public PlaylistDetailDto createPlaylist(User user, CreatePlaylistDto req) {
        if (req.getPlaylistSongs() == null || req.getPlaylistSongs().isEmpty()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Playlist must contain at least one song");
        }

        if (req.getName() == null || req.getName().isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Playlist name is required");
        }

        Playlist playlist = Playlist.builder()
                .user(user)
                .name(req.getName())
                .playlistType(ContentType.USER_UPLOAD)
                .coverImage(req.getCoverImage())
                .build();

        Playlist saved = playlistRepository.save(playlist);
        replacePlaylistSongs(saved, req.getPlaylistSongs());
        return toDetailDto(saved);
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
        if (req.getPlaylistSongs() != null && !req.getPlaylistSongs().isEmpty()) {
            replacePlaylistSongs(playlist, req.getPlaylistSongs());
        }
        if (req.getCoverImage() != null) {
            playlist.setCoverImage(req.getCoverImage().isBlank() ? null : req.getCoverImage());
        }
        playlist.setUpdatedAt(Instant.now());

        Playlist saved = playlistRepository.save(playlist);
        return toDetailDto(saved);
    }

    @Transactional
    public void deletePlaylist(Long playlistId, Long userId) {
        Playlist playlist = findAndAuthorize(playlistId, userId);
        playlistRepository.delete(playlist);
    }

    @Transactional(readOnly = true)
    public byte[] getPlaylistCover(Long playlistId, Long userId) {
        Playlist playlist = findAndAuthorize(playlistId, userId);
        if (playlist.getCoverImage() != null && !playlist.getCoverImage().isBlank()) {
            return CoverDecoder.decodeCoverImage(playlist.getCoverImage());
        }

        List<PlaylistSong> playlistSongs = playlistSongRepository.findByPlaylist_IdOrderById_PositionAsc(playlist.getId());
        if (playlistSongs.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Cover not found");
        }

        Song firstSong = playlistSongs.getFirst().getSong();
        if (firstSong == null || firstSong.getAlbum() == null) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Cover not found");
        }

        return CoverDecoder.decodeCoverImage(firstSong.getAlbum().getCoverImage());
    }

    private Playlist findAndAuthorize(Long playlistId, Long userId) {
        Playlist playlist = playlistRepository.findById(playlistId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Playlist not found"));
        if (!playlist.getUser().getId().equals(userId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Access denied");
        }
        return playlist;
    }

    private PlaylistDetailDto toDetailDto(Playlist playlist) {
        List<PlaylistSong> playlistSongs = playlistSongRepository.findByPlaylist_IdOrderById_PositionAsc(playlist.getId());

        if (playlistSongs.isEmpty()) {
            return playlistMapper.toDetailDto(playlist, List.of());
        }

        List<Long> uniqueSongIds = playlistSongs.stream()
                .map(entry -> entry.getSong().getId())
                .distinct()
                .toList();

        Map<Long, Song> songsById = songRepository.findAllById(uniqueSongIds).stream()
                .collect(Collectors.toMap(Song::getId, Function.identity()));

        Long ownerId = playlist.getUser() == null ? null : playlist.getUser().getId();
        Map<String, SongDto> dtosByFileHash = songEnrichmentService
                .enrich(new ArrayList<>(songsById.values()), ownerId).stream()
                .collect(Collectors.toMap(SongDto::getFileHash, Function.identity()));

        List<PlaylistSongDto> entries = playlistSongs.stream()
                .map(entry -> {
                    Song song = songsById.get(entry.getSong().getId());
                    if (song == null) {
                        return null;
                    }
                    SongDto songDto = dtosByFileHash.get(song.getFileHash());
                    if (songDto == null) {
                        return null;
                    }
                    PlaylistSongDto dto = new PlaylistSongDto();
                    dto.setSong(songDto);
                    dto.setPosition(entry.getId().getPosition());
                    return dto;
                })
                .filter(Objects::nonNull)
                .toList();

        return playlistMapper.toDetailDto(playlist, entries);
    }

    private void replacePlaylistSongs(Playlist playlist, List<PlaylistSongPositionDto> items) {
        if (items == null || items.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Playlist must contain at least one song");
        }

        Set<Integer> usedPositions = new HashSet<>();
        for (PlaylistSongPositionDto item : items) {
            if (item == null || item.getSongFileHash() == null || item.getSongFileHash().isBlank() || item.getPosition() == null || item.getPosition() < 0) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Each song item must include non-empty songFileHash and non-negative position");
            }
            if (!usedPositions.add(item.getPosition())) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Duplicate playlist position: " + item.getPosition());
            }
        }

        List<String> requestedHashes = items.stream()
                .map(PlaylistSongPositionDto::getSongFileHash)
                .distinct()
                .toList();

        Map<String, Song> songsByHash = songRepository.findAllByFileHashIn(requestedHashes).stream()
                .collect(Collectors.toMap(Song::getFileHash, Function.identity()));

        List<PlaylistSong> entries = items.stream()
                .sorted(Comparator.comparingInt(PlaylistSongPositionDto::getPosition))
                .map(item -> {
                    Song song = songsByHash.get(item.getSongFileHash());
                    if (song == null) {
                        throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Song not found for hash: " + item.getSongFileHash());
                    }
                    return PlaylistSong.builder()
                            .id(new PlaylistSongId(playlist.getId(), item.getPosition()))
                            .playlist(playlist)
                            .song(song)
                            .build();
                })
                .toList();

        playlistSongRepository.deleteByPlaylist_Id(playlist.getId());
        playlistSongRepository.saveAll(entries);
    }
}
