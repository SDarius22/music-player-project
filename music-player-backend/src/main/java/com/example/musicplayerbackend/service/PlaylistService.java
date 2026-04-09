package com.example.musicplayerbackend.service;

import com.example.musicplayerbackend.data.PlaylistRepository;
import com.example.musicplayerbackend.data.PlaylistSongRepository;
import com.example.musicplayerbackend.data.SongRepository;
import com.example.musicplayerbackend.data.projection.PlaylistListProjection;
import com.example.musicplayerbackend.domain.*;
import com.example.musicplayerbackend.helpers.CoverDecoder;
import com.example.musicplayerbackend.mapper.PlaylistMapper;
import com.example.musicplayerbackend.mapper.SongMapper;
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
    private final SongMapper songMapper;

    public PlaylistPageDto getPlaylists(Long userId, int page, int size) {
        Page<PlaylistListProjection> result = playlistRepository.findAllWithHashes(userId, PageRequest.of(page, size));

        List<PlaylistDto> content = result.getContent().stream()
                .map(playlistMapper::toDto)
                .toList();

        return playlistMapper.toPageDto(
                content,
                result.getNumber(),
                result.getSize(),
                result.getTotalElements(),
                result.getTotalPages()
        );
    }

    @Transactional
    public PlaylistDetailDto createPlaylist(User user, CreatePlaylistDto req) {
        if (req.getSongFileHashes() == null || req.getSongFileHashes().isEmpty()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Playlist must contain at least one song");
        }

        Playlist playlist = Playlist.builder()
                .user(user)
                .name(req.getName())
                .playlistType(ContentType.USER_UPLOAD)
                .coverImage(req.getCoverImage())
                .build();

        Playlist saved = playlistRepository.save(playlist);
        List<PlaylistSongInput> songsInOrder = resolveSongInputs(req.getSongFileHashes());
        replacePlaylistSongs(saved, songsInOrder);
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
        if (req.getSongFileHashes() != null && !req.getSongFileHashes().isEmpty()) {
            replacePlaylistSongs(playlist, resolveSongInputs(req.getSongFileHashes()));
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

        List<SongDto> songs = playlistSongs.stream()
                .map(entry -> songsById.get(entry.getSong().getId()))
                .filter(Objects::nonNull)
                .map(songMapper::toDto)
                .toList();

        return playlistMapper.toDetailDto(playlist, songs);
    }

    private List<PlaylistSongInput> resolveSongInputs(List<PlaylistSongPositionDto> items) {
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
                .collect(Collectors.toMap(Song::getFileHash, Function.identity(), (left, right) -> left, LinkedHashMap::new));

        return items.stream()
                .map(item -> {
                    Song song = songsByHash.get(item.getSongFileHash());
                    if (song == null) {
                        throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Song not found for hash: " + item.getSongFileHash());
                    }
                    return new PlaylistSongInput(item.getPosition(), song);
                })
                .sorted(Comparator.comparingInt(PlaylistSongInput::position))
                .toList();
    }

    private void replacePlaylistSongs(Playlist playlist, List<PlaylistSongInput> songsInOrder) {
        playlistSongRepository.deleteByPlaylist_Id(playlist.getId());
        if (songsInOrder.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Playlist must contain at least one song");
        }

        List<PlaylistSong> entries = songsInOrder.stream()
                .map(item -> PlaylistSong.builder()
                        .id(new PlaylistSongId(playlist.getId(), item.position()))
                        .playlist(playlist)
                        .song(item.song())
                        .build())
                .toList();

        playlistSongRepository.saveAll(entries);
    }

    private record PlaylistSongInput(int position, Song song) {
    }
}
