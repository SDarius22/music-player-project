package com.example.musicplayerbackend.mapper;

import com.example.musicplayerbackend.domain.Artist;
import com.example.musicplayerbackend.domain.ArtistDto;
import com.example.musicplayerbackend.domain.ArtistExpandedDto;
import com.example.musicplayerbackend.domain.Song;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.MappingConstants;
import org.mapstruct.ReportingPolicy;

import java.util.List;

@Mapper(
        componentModel = MappingConstants.ComponentModel.SPRING,
        unmappedTargetPolicy = ReportingPolicy.IGNORE,
        uses = {SongMapper.class}
)
public interface ArtistMapper {

    @Mapping(target = "hash", source = "hash")
    @Mapping(target = "name", source = "artistName")
    ArtistDto toDto(String hash, String artistName);

    ArtistDto toDto(Artist artist);

    @Mapping(target = "songFileHashes", source = "artist.songs")
    @Mapping(target = "hash", source = "artist.hash")
    @Mapping(target = "name", source = "artist.name")
    ArtistExpandedDto toExpandedDto(Artist artist);

    default List<String> mapToHash(List<Song> value) {
        return value.stream().map(Song::getFileHash).toList();
    }
}
