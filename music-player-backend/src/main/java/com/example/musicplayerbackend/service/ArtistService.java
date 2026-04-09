package com.example.musicplayerbackend.service;

import com.example.musicplayerbackend.data.ArtistRepository;
import com.example.musicplayerbackend.domain.Album;
import com.example.musicplayerbackend.domain.Artist;
import com.example.musicplayerbackend.domain.ArtistDetailDto;
import com.example.musicplayerbackend.domain.ArtistPageDto;
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

@Service
@RequiredArgsConstructor
public class ArtistService {

    private final ArtistRepository artistRepository;
    private final ArtistMapper artistMapper;
    private final SortMapper sortMapper;

    @Transactional(readOnly = true)
    public ArtistPageDto getArtists(String query, Integer page, Integer size, String sort) {
        int safePage = page == null ? 0 : Math.max(page, 0);
        int safeSize = size == null ? 50 : Math.clamp(size, 1, 200);
        query = (query == null || query.isBlank()) ? "" : query;
        Pageable pageable = PageRequest.of(safePage, safeSize, sortMapper.toSort(sort));

        var result = artistRepository.findAllWithHashes(query, pageable);

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
    public ArtistDetailDto getArtistByHash(String artistHash) {
        Artist artist = artistRepository.findByHash(artistHash)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Artist not found"));
        return artistMapper.toDetailDto(artist);
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
