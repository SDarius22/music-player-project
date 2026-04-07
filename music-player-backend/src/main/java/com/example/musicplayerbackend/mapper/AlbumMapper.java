package com.example.musicplayerbackend.mapper;

import com.example.musicplayerbackend.data.projection.AlbumListProjection;
import com.example.musicplayerbackend.domain.Album;
import com.example.musicplayerbackend.domain.AlbumDto;
import com.example.musicplayerbackend.domain.AlbumExpandedDto;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.MappingConstants;
import org.mapstruct.ReportingPolicy;

@Mapper(
        componentModel = MappingConstants.ComponentModel.SPRING,
        unmappedTargetPolicy = ReportingPolicy.IGNORE
)
public interface AlbumMapper {

    Album toEntity(AlbumDto albumDto);

    AlbumDto toDto(Album album);

    @Mapping(target = "songFileHashes", ignore = true)
    @Mapping(target = "artist.hash", source = "artistHash")
    @Mapping(target = "artist.name", source = "artistName")
    AlbumExpandedDto toExpandedDto(AlbumListProjection projection);
}
