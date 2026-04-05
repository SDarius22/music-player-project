package com.example.musicplayerbackend.mapper;

import com.example.musicplayerbackend.data.projection.AlbumListProjection;
import com.example.musicplayerbackend.domain.Album;
import com.example.musicplayerbackend.domain.AlbumDto;
import com.example.musicplayerbackend.domain.AlbumListDto;
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

    @Mapping(target = "photo", source = "coverImage")
    @Mapping(target = "type", expression = "java(album.getAlbumType() != null ? com.example.musicplayerbackend.domain.AlbumDto.TypeEnum.fromValue(album.getAlbumType().name()) : null)")
    AlbumDto toDto(Album album);

    @Mapping(target = "type", expression = "java(projection.getType() != null ? com.example.musicplayerbackend.domain.AlbumListDto.TypeEnum.fromValue(projection.getType()) : null)")
    @Mapping(target = "songFileHashes", ignore = true)
    AlbumListDto toListDto(AlbumListProjection projection);
}
