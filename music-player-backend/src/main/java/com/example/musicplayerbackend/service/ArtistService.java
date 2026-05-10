package com.example.musicplayerbackend.service;

import com.example.musicplayerbackend.data.ArtistRepository;
import com.example.musicplayerbackend.domain.*;
import com.example.musicplayerbackend.helpers.CoverDecoder;
import com.example.musicplayerbackend.mapper.ArtistMapper;
import com.example.musicplayerbackend.mapper.SortMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.Objects;

@Service
@RequiredArgsConstructor
public class ArtistService {

    private final ArtistRepository artistRepository;
    private final ArtistMapper artistMapper;
    private final SortMapper sortMapper;
    private final SongEnrichmentService songEnrichmentService;

    @Transactional(readOnly = true)
    public ArtistPageDto getArtists(String query, Integer page, Integer size, String sort) {
        int safePage = page == null ? 0 : Math.max(page, 0);
        int safeSize = size == null ? 50 : Math.clamp(size, 1, 200);
        query = (query == null || query.isBlank()) ? "" : query;
        Pageable pageable = PageRequest.of(safePage, safeSize, sortMapper.toSort(sort));

        var result = artistRepository.findAllByNameContainingIgnoreCase(query, pageable);

        var content = result.getContent()
                .stream().map(artistMapper::toExpandedDto)
                .toList();

        return new ArtistPageDto(
                content,
                result.getNumber(),
                result.getSize(),
                result.getTotalElements(),
                result.getTotalPages()
        );
    }

    @Transactional(readOnly = true)
    public ArtistExpandedDto getArtistByHash(String artistHash, Long userId) {
        Artist artist = artistRepository.findByHash(artistHash)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Artist not found"));

        ArtistExpandedDto dto = artistMapper.toExpandedDto(artist);
        List<Song> filteredSongs = artist.getSongs().stream()
                .filter(song -> Objects.isNull(song.getOwnerId()) || Objects.equals(song.getOwnerId(), userId))
                .toList();
        dto.setSongFileHashes(filteredSongs.stream()
                .map(Song::getFileHash)
                .toList());
        return dto;
    }

    @Transactional(readOnly = true)
    public byte[] getArtistCover(String artistHash) {
        Artist artist = artistRepository.findByHash(artistHash)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Artist not found"));

        if (artist.getAlbums() == null || artist.getAlbums().isEmpty()) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "No albums found for artist");
        }

        String coverImage = artist.getAlbums().stream()
                .map(Album::getCoverImage)
                .filter(c -> c != null && !c.isBlank())
                .findFirst()
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Cover not found"));

        return CoverDecoder.decodeCoverImage(coverImage);
    }
}
