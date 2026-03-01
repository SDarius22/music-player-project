package com.example.musicplayerbackend.mapper;

import com.example.musicplayerbackend.domain.Song;
import com.example.musicplayerbackend.domain.SongDto;
import org.mapstruct.Mapper;
import org.mapstruct.MappingConstants;
import org.mapstruct.ReportingPolicy;

import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;

@Mapper(
        componentModel = MappingConstants.ComponentModel.SPRING,
        uses = {ArtistMapper.class, AlbumMapper.class},
        unmappedTargetPolicy = ReportingPolicy.IGNORE
)
public interface SongMapper {

    SongDto toDto(Song song);

    Song toEntity(SongDto songDto);

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