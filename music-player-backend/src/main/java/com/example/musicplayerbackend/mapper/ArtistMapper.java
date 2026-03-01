package com.example.musicplayerbackend.mapper;

import com.example.musicplayerbackend.domain.Artist;
import com.example.musicplayerbackend.domain.ArtistDto;
import org.mapstruct.Mapper;
import org.mapstruct.MappingConstants;
import org.mapstruct.ReportingPolicy;

@Mapper(
        componentModel = MappingConstants.ComponentModel.SPRING,
        unmappedTargetPolicy = ReportingPolicy.IGNORE
)
public interface ArtistMapper {

    ArtistDto toDto(Artist artist);

    Artist toEntity(ArtistDto artistDto);
}