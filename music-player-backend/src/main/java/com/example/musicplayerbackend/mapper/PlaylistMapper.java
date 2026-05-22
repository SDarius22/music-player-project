package com.example.musicplayerbackend.mapper;

import com.example.musicplayerbackend.data.projection.PlaylistListProjection;
import com.example.musicplayerbackend.domain.PlaylistDto;
import java.util.Arrays;
import java.util.List;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.MappingConstants;
import org.mapstruct.Named;
import org.mapstruct.ReportingPolicy;

@Mapper(
    componentModel = MappingConstants.ComponentModel.SPRING,
    unmappedTargetPolicy = ReportingPolicy.IGNORE)
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
