package com.example.musicplayerbackend.service;

import com.example.musicplayerbackend.data.AlbumRepository;
import com.example.musicplayerbackend.data.SongRepository;
import com.example.musicplayerbackend.data.specification.SongSpecification;
import com.example.musicplayerbackend.domain.*;
import com.example.musicplayerbackend.helpers.CoverDecoder;
import com.example.musicplayerbackend.mapper.AlbumMapper;
import com.example.musicplayerbackend.mapper.SortMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.util.Comparator;
import java.util.List;
import java.util.Objects;

@Service
@RequiredArgsConstructor
public class AlbumService {

    private final AlbumRepository albumRepository;
    private final SongRepository songRepository;
    private final AlbumMapper albumMapper;
    private final SortMapper sortMapper;
    private final SongEnrichmentService songEnrichmentService;

    @Transactional(readOnly = true)
    public AlbumPageDto getAlbums(String query, Integer page, Integer size, String sort) {
        int safePage = page == null ? 0 : Math.max(page, 0);
        int safeSize = size == null ? 50 : Math.clamp(size, 1, 200);
        query = (query == null || query.isBlank()) ? "" : query;
        var pageable = PageRequest.of(safePage, safeSize, sortMapper.toSort(sort));

        var result = albumRepository.findAllByNameContainingIgnoreCase(query, pageable);

        var content = result.getContent().stream()
                .map(album -> albumMapper.toExpandedDto(album, getMainArtist(album)))
                .toList();

        return new AlbumPageDto(
                content,
                result.getNumber(),
                result.getSize(),
                result.getTotalElements(),
                result.getTotalPages()
        );
    }

    @Transactional(readOnly = true)
    public AlbumExpandedDto getAlbumByHash(String albumHash, Long userId) {
        Album album = albumRepository.findByHash(albumHash)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Album not found"));

        AlbumExpandedDto dto = albumMapper.toExpandedDto(album, getMainArtist(album));
        List<Song> filteredSongs = album.getSongs().stream()
                .filter(song -> Objects.isNull(song.getOwnerId()) || Objects.equals(song.getOwnerId(), userId))
                .toList();
        dto.setSongFileHashes(filteredSongs.stream()
                .map(Song::getFileHash)
                .toList());
        dto.setDurationInSeconds(filteredSongs.stream()
                .filter(song -> song.getDurationInSeconds() != null)
                .mapToInt(Song::getDurationInSeconds)
                .sum());
        return dto;
    }

    @Transactional(readOnly = true)
    public byte[] getAlbumCover(String albumHash) {
        Album album = albumRepository.findByHash(albumHash)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Album not found"));
        return CoverDecoder.decodeCoverImage(album.getCoverImage());
    }

    @Transactional(readOnly = true)
    public SongPageDto getAlbumSongs(String albumHash, Long userId, Integer page, Integer size) {
        Album album = albumRepository.findByHash(albumHash)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Album not found"));

        int safePage = page == null ? 0 : Math.max(page, 0);
        int safeSize = size == null ? 50 : Math.clamp(size, 1, 200);
        Pageable pageable = PageRequest.of(safePage, safeSize, Sort.by(
                Sort.Order.asc("discNumber").nullsLast(),
                Sort.Order.asc("trackNumber").nullsLast(),
                Sort.Order.asc("name"),
                Sort.Order.asc("fileHash")
        ));

        Specification<Song> spec = SongSpecification.visibleToUser(userId)
                .and(SongSpecification.hasAlbumHash(album.getHash()));

        var result = songRepository.findAll(spec, pageable);
        var content = songEnrichmentService.enrich(result.getContent(), userId);

        return new SongPageDto(content, result.getNumber(), result.getSize(),
                result.getTotalElements(), result.getTotalPages());
    }

    private Artist getMainArtist(Album album) {
        if (album.getArtists() == null || album.getArtists().isEmpty()) {
            return null;
        }

        Artist fallbackArtist = album.getArtists().iterator().next();
        var songs = album.getSongs();

        Artist selected = album.getArtists().stream()
                .max(Comparator.comparingLong((Artist artist) -> countSongsForArtist(songs, artist))
                        .thenComparing(artist -> firstSongIdForArtist(songs, artist), Comparator.reverseOrder())
                        .thenComparing(Artist::getId, Comparator.nullsLast(Comparator.reverseOrder())))
                .orElse(fallbackArtist);

        return countSongsForArtist(songs, selected) > 0 ? selected : fallbackArtist;
    }

    private long countSongsForArtist(List<Song> songs, Artist artist) {
        if (songs == null || artist == null) {
            return 0;
        }
        return songs.stream()
                .filter(song -> song.getArtist() != null
                        && Objects.equals(song.getArtist().getId(), artist.getId()))
                .count();
    }

    private Long firstSongIdForArtist(List<Song> songs, Artist artist) {
        if (songs == null || artist == null) {
            return Long.MAX_VALUE;
        }
        return songs.stream()
                .filter(song -> song.getArtist() != null
                        && Objects.equals(song.getArtist().getId(), artist.getId()))
                .map(Song::getId)
                .filter(Objects::nonNull)
                .min(Long::compareTo)
                .orElse(Long.MAX_VALUE);
    }
}
