package com.example.musicplayerbackend.mapper;

import com.example.musicplayerbackend.data.projection.PlaylistListProjection;
import com.example.musicplayerbackend.domain.PlaylistDto;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.MappingConstants;
import org.mapstruct.ReportingPolicy;

@Mapper(
        componentModel = MappingConstants.ComponentModel.SPRING,
        unmappedTargetPolicy = ReportingPolicy.IGNORE
)
public interface PlaylistMapper {

    @Mapping(target = "songFileHashes", ignore = true)
    PlaylistDto toDto(PlaylistListProjection projection);
}
