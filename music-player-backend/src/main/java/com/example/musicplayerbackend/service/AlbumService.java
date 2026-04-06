package com.example.musicplayerbackend.service;

import com.example.musicplayerbackend.data.AlbumRepository;
import com.example.musicplayerbackend.domain.*;
import com.example.musicplayerbackend.helpers.CoverDecoder;
import com.example.musicplayerbackend.mapper.AlbumMapper;
import com.example.musicplayerbackend.mapper.SongMapper;
import com.example.musicplayerbackend.mapper.SortMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.util.Arrays;
import java.util.List;

@Service
@RequiredArgsConstructor
public class AlbumService {

    private final AlbumRepository albumRepository;
    private final AlbumMapper albumMapper;
    private final SongMapper songMapper;
    private final SortMapper sortMapper;

    @Transactional(readOnly = true)
    public AlbumPageDto getAlbums(String query, Integer page, Integer size, String sort) {
        int safePage = page == null ? 0 : Math.max(page, 0);
        int safeSize = size == null ? 50 : Math.min(Math.max(size, 1), 200);
        query = (query == null || query.isBlank()) ? "" : query;
        var pageable = PageRequest.of(safePage, safeSize, sortMapper.toSort(sort));

        var result = albumRepository.findAllWithHashes(query, pageable);

        var content = result.getContent().stream().map(proj -> {
            AlbumExpandedDto dto = albumMapper.toExpandedDto(proj);
            String csv = proj.getSongFileHashesCsv();
            dto.setSongFileHashes(csv != null && !csv.isBlank()
                    ? Arrays.stream(csv.split(",")).toList() : List.of());
            return dto;
        }).toList();

        return new AlbumPageDto(content, result.getNumber(), result.getSize(),
                result.getTotalElements(), result.getTotalPages());
    }

    public AlbumDetailDto getAlbumByHash(String albumHash) {
        Album album = albumRepository.findByHash(albumHash)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Album not found"));

        ArtistDto artistDto = null;
        if (album.getArtist() != null) {
            artistDto = new ArtistDto();
            artistDto.setHash(album.getArtist().getHash());
            artistDto.setName(album.getArtist().getName());
        }

        List<SongDto> songs = album.getSongs() == null ? List.of() :
                album.getSongs().stream().map(songMapper::toDto).toList();

        AlbumDetailDto dto = new AlbumDetailDto();
        dto.setHash(album.getHash());
        dto.setName(album.getName());
        dto.setArtist(artistDto);
        dto.setSongs(songs);
        return dto;
    }

    public byte[] getAlbumCover(String albumHash) {
        Album album = albumRepository.findByHash(albumHash)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Album not found"));
        return CoverDecoder.decodeCoverImage(album.getCoverImage());
    }
}
