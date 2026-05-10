package com.example.musicplayerbackend.mapper;

import com.example.musicplayerbackend.data.projection.PlaylistListProjection;
import com.example.musicplayerbackend.domain.PlaylistDto;
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

    @Named("csvToHashes")
    default List<String> csvToHashes(String csv) {
        if (csv == null || csv.isBlank()) {
            return List.of();
        }
        return Arrays.stream(csv.split(",")).toList();
    }

}
