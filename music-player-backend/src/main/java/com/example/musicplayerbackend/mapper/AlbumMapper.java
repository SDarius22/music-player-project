package com.example.musicplayerbackend.mapper;

import com.example.musicplayerbackend.data.projection.AlbumListProjection;
import com.example.musicplayerbackend.domain.Album;
import com.example.musicplayerbackend.domain.AlbumDetailDto;
import com.example.musicplayerbackend.domain.AlbumDto;
import com.example.musicplayerbackend.domain.AlbumExpandedDto;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.MappingConstants;
import org.mapstruct.ReportingPolicy;

@Mapper(
        componentModel = MappingConstants.ComponentModel.SPRING,
        unmappedTargetPolicy = ReportingPolicy.IGNORE,
        uses = {ArtistMapper.class}
)
public interface AlbumMapper {

    AlbumDto toDto(Album album);

    AlbumDetailDto toDetailDto(Album album);

    @Mapping(target = "songFileHashes", source = "songFileHashesCsv")
    @Mapping(target = "artist", expression = "java(artistMapper.toDto(projection.getArtistHash(), projection.getArtistName()))")
    AlbumExpandedDto toExpandedDto(AlbumListProjection projection);
}
