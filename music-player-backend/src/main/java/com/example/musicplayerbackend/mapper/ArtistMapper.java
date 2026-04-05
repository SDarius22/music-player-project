package com.example.musicplayerbackend.mapper;

import com.example.musicplayerbackend.data.projection.ArtistListProjection;
import com.example.musicplayerbackend.domain.Artist;
import com.example.musicplayerbackend.domain.ArtistDto;
import com.example.musicplayerbackend.domain.ArtistExpandedDto;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.MappingConstants;
import org.mapstruct.ReportingPolicy;

@Mapper(
        componentModel = MappingConstants.ComponentModel.SPRING,
        unmappedTargetPolicy = ReportingPolicy.IGNORE
)
public interface ArtistMapper {

    ArtistDto toDto(Artist artist);

    Artist toEntity(ArtistDto artistDto);

    @Mapping(target = "songFileHashes", ignore = true)
    ArtistExpandedDto toExpandedDto(ArtistListProjection projection);
}
