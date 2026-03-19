package com.example.musicplayerbackend.service;

import com.example.musicplayerbackend.data.ArtistRepository;
import com.example.musicplayerbackend.domain.Artist;
import com.example.musicplayerbackend.domain.AlbumDto;
import com.example.musicplayerbackend.domain.ArtistDetailDto;
import com.example.musicplayerbackend.domain.ArtistDto;
import com.example.musicplayerbackend.domain.ArtistPageDto;
import com.example.musicplayerbackend.mapper.AlbumMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;

@Service
@RequiredArgsConstructor
public class ArtistService {

    private final ArtistRepository artistRepository;
    private final AlbumMapper albumMapper;

    public ArtistPageDto getArtists(String q, int page, int size, String sort) {
        String query = (q == null || q.isBlank()) ? null : q;
        Pageable pageable = PageRequest.of(page, size, parseSort(sort));
        Page<Artist> result = artistRepository.findAllByQuery(query, pageable);

        List<ArtistDto> content = result.getContent().stream().map(a -> {
            ArtistDto dto = new ArtistDto();
            dto.setId(a.getId());
            dto.setName(a.getName());
            return dto;
        }).toList();

        return new ArtistPageDto(content, result.getNumber(), result.getSize(),
                result.getTotalElements(), result.getTotalPages());
    }

    public ArtistDetailDto getArtistById(Long id) {
        Artist artist = artistRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Artist not found"));

        List<AlbumDto> albums = artist.getAlbums() == null ? List.of() :
                artist.getAlbums().stream().map(albumMapper::toDto).toList();

        ArtistDetailDto dto = new ArtistDetailDto();
        dto.setId(artist.getId());
        dto.setName(artist.getName());
        dto.setAlbums(albums);
        return dto;
    }

    public byte[] getArtistCover(Long id) {
        Artist artist = artistRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Artist not found"));

        if (artist.getAlbums() == null || artist.getAlbums().isEmpty()) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "No albums found for artist");
        }

        String coverImage = artist.getAlbums().stream()
                .map(a -> a.getCoverImage())
                .filter(c -> c != null && !c.isBlank())
                .findFirst()
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Cover not found"));

        return AlbumService.decodeCoverImage(coverImage);
    }

    private Sort parseSort(String sort) {
        if (sort == null || sort.isBlank()) return Sort.by(Sort.Order.asc("name"));
        String[] parts = sort.split(",", 2);
        String dir = parts.length > 1 ? parts[1].trim() : "asc";
        return "desc".equals(dir) ? Sort.by(Sort.Order.desc("name")) : Sort.by(Sort.Order.asc("name"));
    }
}
