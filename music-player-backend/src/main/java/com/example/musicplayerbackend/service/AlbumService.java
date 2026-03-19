package com.example.musicplayerbackend.service;

import com.example.musicplayerbackend.data.AlbumRepository;
import com.example.musicplayerbackend.domain.*;
import com.example.musicplayerbackend.mapper.AlbumMapper;
import com.example.musicplayerbackend.mapper.SongMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import java.util.Base64;
import java.util.List;

@Service
@RequiredArgsConstructor
public class AlbumService {

    private final AlbumRepository albumRepository;
    private final AlbumMapper albumMapper;
    private final SongMapper songMapper;

    public static byte[] decodeCoverImage(String coverImage) {
        if (coverImage == null || coverImage.isBlank()) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Cover not found");
        }
        String base64 = coverImage;
        if (coverImage.startsWith("data:")) {
            int commaIdx = coverImage.indexOf(',');
            if (commaIdx >= 0) {
                base64 = coverImage.substring(commaIdx + 1);
            }
        }
        try {
            return Base64.getDecoder().decode(base64.trim());
        } catch (IllegalArgumentException e) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Cover not found");
        }
    }

    public AlbumPageDto getAlbums(String q, int page, int size, String sort) {
        String query = (q == null || q.isBlank()) ? null : q;
        Pageable pageable = PageRequest.of(page, size, parseSort(sort));
        Page<Album> result = albumRepository.findAllByNameContainingIgnoreCase(query, pageable);
        List<AlbumDto> content = result.getContent().stream().map(albumMapper::toDto).toList();
        return new AlbumPageDto(content, result.getNumber(), result.getSize(),
                result.getTotalElements(), result.getTotalPages());
    }

    public AlbumDetailDto getAlbumById(Long id) {
        Album album = albumRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Album not found"));

        ArtistDto artistDto = null;
        if (album.getArtist() != null) {
            artistDto = new ArtistDto();
            artistDto.setId(album.getArtist().getId());
            artistDto.setName(album.getArtist().getName());
        }

        List<SongDto> songs = album.getSongs() == null ? List.of() :
                album.getSongs().stream().map(songMapper::toDto).toList();

        AlbumDetailDto dto = new AlbumDetailDto();
        dto.setId(album.getId());
        dto.setName(album.getName());
        dto.setPhoto(album.getCoverImage());
        dto.setArtist(artistDto);
        dto.setSongs(songs);
        return dto;
    }

    public byte[] getAlbumCover(Long id) {
        Album album = albumRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Album not found"));
        return decodeCoverImage(album.getCoverImage());
    }

    private Sort parseSort(String sort) {
        if (sort == null || sort.isBlank()) return Sort.by(Sort.Order.asc("name"));
        String[] parts = sort.split(",", 2);
        String dir = parts.length > 1 ? parts[1].trim() : "asc";
        return "desc".equals(dir) ? Sort.by(Sort.Order.desc("name")) : Sort.by(Sort.Order.asc("name"));
    }
}
