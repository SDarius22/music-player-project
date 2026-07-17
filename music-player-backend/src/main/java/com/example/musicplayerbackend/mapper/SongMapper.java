package com.example.musicplayerbackend.mapper;

import com.example.musicplayerbackend.domain.Song;
import com.example.musicplayerbackend.domain.SongDto;
import com.example.musicplayerbackend.domain.UserLibrary;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.MappingConstants;
import org.mapstruct.ReportingPolicy;

@Mapper(
    componentModel = MappingConstants.ComponentModel.SPRING,
    unmappedTargetPolicy = ReportingPolicy.IGNORE)
public interface SongMapper {

  @Mapping(target = "artist.hash", source = "artist.hash")
  @Mapping(target = "artist.name", source = "artist.name")
  @Mapping(target = "album.hash", source = "album.hash")
  @Mapping(target = "album.name", source = "album.name")
  @Mapping(target = "durationInSeconds", source = "song.durationInSeconds")
  @Mapping(target = "trackNumber", source = "song.trackNumber")
  @Mapping(target = "discNumber", source = "song.discNumber")
  @Mapping(target = "fileHash", source = "song.fileHash")
  @Mapping(target = "name", source = "song.name")
  @Mapping(target = "year", source = "song.releaseYear")
  SongDto toDto(Song song);

  default SongDto toDto(Song song, UserLibrary entry) {
    SongDto dto = toDto(song);
    if (dto == null) {
      return null;
    }
    if (entry == null || Boolean.TRUE.equals(entry.getIsDeleted())) {
      dto.setLastPlayed(null);
      dto.setPlayCount(0L);
      dto.setLikedByUser(false);
    } else {
      dto.setLastPlayed(map(entry.getLastPlayed()));
      Long playCount = entry.getPlayCount();
      dto.setPlayCount(playCount == null ? Long.valueOf(0L) : playCount);
      dto.setLikedByUser(Boolean.TRUE.equals(entry.getLiked()));
    }
    return dto;
  }

  default List<SongDto> toDtoList(List<Song> songs) {
    if (songs == null) {
      return List.of();
    }
    return songs.stream().map(this::toDto).toList();
  }

  default OffsetDateTime map(Instant value) {
    if (value == null) {
      return null;
    }
    return value.atOffset(ZoneOffset.UTC);
  }

  default Instant map(OffsetDateTime value) {
    if (value == null) {
      return null;
    }
    return value.toInstant();
  }
}
