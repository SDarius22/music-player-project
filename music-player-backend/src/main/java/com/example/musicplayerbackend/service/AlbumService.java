package com.example.musicplayerbackend.service;

import com.example.musicplayerbackend.data.AlbumRepository;
import com.example.musicplayerbackend.domain.Album;
import com.example.musicplayerbackend.domain.AlbumDetailDto;
import com.example.musicplayerbackend.domain.AlbumPageDto;
import com.example.musicplayerbackend.helpers.CoverDecoder;
import com.example.musicplayerbackend.mapper.AlbumMapper;
import com.example.musicplayerbackend.mapper.SortMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@Service
@RequiredArgsConstructor
public class AlbumService {

    private final AlbumRepository albumRepository;
    private final AlbumMapper albumMapper;
    private final SortMapper sortMapper;

    @Transactional(readOnly = true)
    public AlbumPageDto getAlbums(String query, Integer page, Integer size, String sort) {
        int safePage = page == null ? 0 : Math.max(page, 0);
        int safeSize = size == null ? 50 : Math.clamp(size, 1, 200);
        query = (query == null || query.isBlank()) ? "" : query;
        var pageable = PageRequest.of(safePage, safeSize, sortMapper.toSort(sort));

        var result = albumRepository.findAllWithHashes(query, pageable);

        var content = result.getContent().stream()
                .map(albumMapper::toExpandedDto)
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
    public AlbumDetailDto getAlbumByHash(String albumHash) {
        Album album = albumRepository.findByHash(albumHash)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Album not found"));

        return albumMapper.toDetailDto(album);
    }

    @Transactional(readOnly = true)
    public byte[] getAlbumCover(String albumHash) {
        Album album = albumRepository.findByHash(albumHash)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Album not found"));
        return CoverDecoder.decodeCoverImage(album.getCoverImage());
    }
}
