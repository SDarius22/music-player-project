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
import org.springframework.data.domain.Sort;
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

    public PlaylistPageDto getPlaylists(Long userId, String q, String sort, Boolean indestructibleFilter, Boolean includeQueue, int page, int size) {
        String search = (q == null || q.isBlank()) ? "" : q.trim();
        Page<PlaylistListProjection> result = playlistRepository.findAllWithHashes(
                userId, search, indestructibleFilter,
                PageRequest.of(page, size, parsePlaylistSort(sort)));

        List<PlaylistDto> content = new ArrayList<>(result.getContent().stream()
                .map(playlistMapper::toDto)
                .toList());

        if (Boolean.TRUE.equals(includeQueue) && page == 0) {
            content.removeIf(p -> DefaultPlaylistService.QUEUE.equals(p.getName()));
            playlistRepository.findAllWithHashes(userId, DefaultPlaylistService.QUEUE, null, PageRequest.of(0, 50))
                    .getContent().stream()
                    .filter(p -> DefaultPlaylistService.QUEUE.equals(p.getName()))
                    .findFirst()
                    .map(playlistMapper::toDto)
                    .ifPresent(content::addFirst);
        }

        return new PlaylistPageDto(
                content,
                result.getNumber(),
                result.getSize(),
                result.getTotalElements(),
                result.getTotalPages()
        );
    }

    public PlaylistExpandedDto getPlaylistByName(Long userId, String name) {
        if (name == null || name.isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "name is required");
        }
        Playlist playlist = playlistRepository.findByUser_IdAndName(userId, name)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Playlist not found"));
        return toDetailDto(playlist);
    }

    private Sort parsePlaylistSort(String sort) {
        if (sort == null || sort.isBlank()) {
            return Sort.by(Sort.Order.asc("name"));
        }
        String[] parts = sort.split(",", 2);
        String property = parts[0].trim();
        String dir = parts.length > 1 ? parts[1].trim().toLowerCase() : "asc";

        // Native query — map to SQL column names.
        String column = switch (property) {
            case "createdAt", "created_at" -> "created_at";
            default -> "name";
        };
        return "desc".equals(dir)
                ? Sort.by(Sort.Order.desc(column))
                : Sort.by(Sort.Order.asc(column));
    }

    @Transactional
    public PlaylistExpandedDto createPlaylist(User user, CreatePlaylistDto req) {
        if (req.getPlaylistSongs() == null || req.getPlaylistSongs().isEmpty()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Playlist must contain at least one song");
        }

        if (req.getName() == null || req.getName().isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Playlist name is required");
        }

        if (playlistRepository.existsByUser_IdAndName(user.getId(), req.getName())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Playlist with this name already exists");
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

    public PlaylistExpandedDto getPlaylistById(Long playlistId, Long userId) {
        Playlist playlist = findAndAuthorize(playlistId, userId);
        return toDetailDto(playlist);
    }

    @Transactional
    public PlaylistExpandedDto updatePlaylist(Long playlistId, Long userId, UpdatePlaylistDto req) {
        Playlist playlist = findAndAuthorize(playlistId, userId);
        if (req.getName() != null && !req.getName().equals(playlist.getName())) {
            if (playlistRepository.existsByUser_IdAndName(userId, req.getName())) {
                throw new ResponseStatusException(HttpStatus.CONFLICT, "Playlist with this name already exists");
            }
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
        if (Boolean.TRUE.equals(playlist.getIndestructible())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Playlist cannot be deleted");
        }
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
