package com.example.musicplayerbackend.service;

import com.example.musicplayerbackend.data.ArtistRepository;
import com.example.musicplayerbackend.data.projection.ArtistListProjection;
import com.example.musicplayerbackend.domain.*;
import com.example.musicplayerbackend.helpers.CoverDecoder;
import com.example.musicplayerbackend.mapper.ArtistMapper;
import com.example.musicplayerbackend.mapper.SongMapper;
import com.example.musicplayerbackend.mapper.SortMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.util.Arrays;
import java.util.List;

@Service
@RequiredArgsConstructor
public class ArtistService {

    private final ArtistRepository artistRepository;
    private final ArtistMapper artistMapper;
    private final SortMapper sortMapper;
    private final SongMapper songMapper;

    @Transactional(readOnly = true)
    public ArtistPageDto getArtists(String query, Integer page, Integer size, String sort) {
        int safePage = page == null ? 0 : Math.max(page, 0);
        int safeSize = size == null ? 50 : Math.min(Math.max(size, 1), 200);
        query = (query == null || query.isBlank()) ? "" : query;
        Pageable pageable = PageRequest.of(safePage, safeSize, sortMapper.toSort(sort));

        Page<ArtistListProjection> result = artistRepository.findAllWithHashes(query, pageable);

        List<ArtistExpandedDto> content = result.getContent().stream().map(proj -> {
            ArtistExpandedDto dto = artistMapper.toExpandedDto(proj);
            String csv = proj.getSongFileHashesCsv();
            dto.setSongFileHashes(csv != null && !csv.isBlank()
                    ? Arrays.stream(csv.split(",")).toList() : List.of());
            return dto;
        }).toList();

        return new ArtistPageDto(content, result.getNumber(), result.getSize(),
                result.getTotalElements(), result.getTotalPages());
    }

    @Transactional(readOnly = true)
    public ArtistDetailDto getArtistById(Long id) {
        Artist artist = artistRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Artist not found"));

        List<SongDto> songs = artist.getSongs() == null ? List.of() :
                artist.getSongs().stream().map(songMapper::toDto).toList();

        ArtistDetailDto dto = new ArtistDetailDto();
        dto.setId(artist.getId());
        dto.setName(artist.getName());
        dto.setSongs(songs);
        return dto;
    }

    public byte[] getArtistCover(Long id) {
        Artist artist = artistRepository.findById(id)
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
