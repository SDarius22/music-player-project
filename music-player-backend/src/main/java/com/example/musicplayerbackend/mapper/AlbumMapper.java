package com.example.musicplayerbackend.mapper;

import com.example.musicplayerbackend.domain.Album;
import com.example.musicplayerbackend.domain.AlbumDto;
import com.example.musicplayerbackend.domain.AlbumExpandedDto;
import com.example.musicplayerbackend.domain.Artist;
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
    AlbumExpandedDto toExpandedDto(Album album, Artist mainArtist);
}
