package com.example.musicplayerbackend.mapper;

import com.example.musicplayerbackend.domain.Album;
import com.example.musicplayerbackend.domain.AlbumDto;
import com.example.musicplayerbackend.domain.AlbumExpandedDto;
import com.example.musicplayerbackend.domain.Artist;
import com.example.musicplayerbackend.domain.Song;
import java.util.List;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.MappingConstants;
import org.mapstruct.Named;
import org.mapstruct.ReportingPolicy;

@Mapper(
    componentModel = MappingConstants.ComponentModel.SPRING,
    unmappedTargetPolicy = ReportingPolicy.IGNORE,
    uses = {ArtistMapper.class})
public interface AlbumMapper {

  AlbumDto toDto(Album album);

  @Mapping(target = "artist", source = "mainArtist")
  @Mapping(target = "hash", source = "album.hash")
  @Mapping(target = "name", source = "album.name")
  @Mapping(
      target = "songFileHashes",
      source = "album.songs",
      qualifiedByName = "albumSongsToHashes")
  AlbumExpandedDto toExpandedDto(Album album, Artist mainArtist);

  @Named("albumSongsToHashes")
  default List<String> mapToHash(List<Song> value) {
    if (value == null) {
      return List.of();
    }
    return value.stream().map(Song::getFileHash).toList();
  }
}
