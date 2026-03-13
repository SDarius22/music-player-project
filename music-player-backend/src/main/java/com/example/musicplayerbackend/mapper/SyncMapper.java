package com.example.musicplayerbackend.mapper;

import com.example.musicplayerbackend.domain.SongSyncDto;
import com.example.musicplayerbackend.domain.UserLibrary;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.MappingConstants;
import org.mapstruct.ReportingPolicy;

import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;

@Mapper(
        componentModel = MappingConstants.ComponentModel.SPRING,
        unmappedTargetPolicy = ReportingPolicy.IGNORE
)
public interface SyncMapper {

    @Mapping(source = "song.id", target = "songId")
    @Mapping(source = "song", target = "songMetadata")
    @Mapping(source = "liked", target = "likedByUser")
    @Mapping(target = "playCountDelta", constant = "0")
    SongSyncDto toDto(UserLibrary userLibrary);


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