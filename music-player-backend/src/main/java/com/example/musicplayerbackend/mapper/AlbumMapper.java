package com.example.musicplayerbackend.mapper;

import com.example.musicplayerbackend.domain.Album;
import com.example.musicplayerbackend.domain.AlbumDto;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.MappingConstants;
import org.mapstruct.ReportingPolicy;

@Mapper(
        componentModel = MappingConstants.ComponentModel.SPRING,
        unmappedTargetPolicy = ReportingPolicy.IGNORE
)
public interface AlbumMapper {

    @Mapping(target = "photo", source = "coverImage")
    @Mapping(target = "type", expression = "java(album.getAlbumType() != null ? com.example.musicplayerbackend.domain.AlbumDto.TypeEnum.fromValue(album.getAlbumType().name()) : null)")
    AlbumDto toDto(Album album);

    Album toEntity(AlbumDto albumDto);
}
