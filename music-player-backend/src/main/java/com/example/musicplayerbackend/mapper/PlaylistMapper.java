package com.example.musicplayerbackend.mapper;

import com.example.musicplayerbackend.data.projection.PlaylistListProjection;
import com.example.musicplayerbackend.domain.Playlist;
import com.example.musicplayerbackend.domain.PlaylistDetailDto;
import com.example.musicplayerbackend.domain.PlaylistDto;
import com.example.musicplayerbackend.domain.PlaylistPageDto;
import com.example.musicplayerbackend.domain.SongDto;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.MappingConstants;
import org.mapstruct.Named;
import org.mapstruct.ReportingPolicy;

import java.util.Arrays;
import java.util.List;

@Mapper(
        componentModel = MappingConstants.ComponentModel.SPRING,
        unmappedTargetPolicy = ReportingPolicy.IGNORE
)
public interface PlaylistMapper {

    @Mapping(target = "songFileHashes", source = "songFileHashesCsv", qualifiedByName = "csvToHashes")
    PlaylistDto toDto(PlaylistListProjection projection);

    @Mapping(target = "id", source = "playlist.id")
    @Mapping(target = "name", source = "playlist.name")
    @Mapping(target = "songs", source = "songs")
    PlaylistDetailDto toDetailDto(Playlist playlist, List<SongDto> songs);

    @Mapping(target = "content", source = "content")
    @Mapping(target = "page", source = "pageNumber")
    @Mapping(target = "size", source = "size")
    @Mapping(target = "totalElements", source = "totalElements")
    @Mapping(target = "totalPages", source = "totalPages")
    PlaylistPageDto toPageDto(List<PlaylistDto> content, int pageNumber, int size, long totalElements, int totalPages);

    @Named("csvToHashes")
    default List<String> csvToHashes(String csv) {
        if (csv == null || csv.isBlank()) {
            return List.of();
        }
        return Arrays.stream(csv.split(",")).toList();
    }

}
