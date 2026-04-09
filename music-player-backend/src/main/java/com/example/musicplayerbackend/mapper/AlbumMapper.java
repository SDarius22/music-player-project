package com.example.musicplayerbackend.mapper;

import com.example.musicplayerbackend.domain.*;
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

    @Mapping(target = "artist", source = "mainArtist")
    @Mapping(target = "hash", source = "album.hash")
    @Mapping(target = "name", source = "album.name")
    @Mapping(target = "songs", source = "album.songs")
    AlbumDetailDto toDetailDto(Album album, Artist mainArtist);

    @Mapping(target = "songFileHashes", source = "album.songs")
    @Mapping(target = "artist", source = "mainArtist")
    @Mapping(target = "hash", source = "album.hash")
    @Mapping(target = "name", source = "album.name")
    AlbumExpandedDto toExpandedDto(Album album, Artist mainArtist);
}
