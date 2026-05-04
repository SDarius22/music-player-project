package com.example.musicplayerbackend.mapper;

import com.example.musicplayerbackend.data.projection.PlaylistListProjection;
import com.example.musicplayerbackend.domain.Playlist;
import com.example.musicplayerbackend.domain.PlaylistDetailDto;
import com.example.musicplayerbackend.domain.PlaylistDto;
import com.example.musicplayerbackend.domain.PlaylistSongDto;
import org.mapstruct.*;

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
    @Mapping(target = "playlistSongs", source = "playlistSongs")
    PlaylistDetailDto toDetailDto(Playlist playlist, List<PlaylistSongDto> playlistSongs);

    @Named("csvToHashes")
    default List<String> csvToHashes(String csv) {
        if (csv == null || csv.isBlank()) {
            return List.of();
        }
        return Arrays.stream(csv.split(",")).toList();
    }

}
