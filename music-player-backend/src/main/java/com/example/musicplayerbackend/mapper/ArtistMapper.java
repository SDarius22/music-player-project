package com.example.musicplayerbackend.mapper;

import com.example.musicplayerbackend.data.projection.ArtistListProjection;
import com.example.musicplayerbackend.domain.Artist;
import com.example.musicplayerbackend.domain.ArtistDetailDto;
import com.example.musicplayerbackend.domain.ArtistDto;
import com.example.musicplayerbackend.domain.ArtistExpandedDto;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.MappingConstants;
import org.mapstruct.ReportingPolicy;

import java.util.List;

@Mapper(
        componentModel = MappingConstants.ComponentModel.SPRING,
        unmappedTargetPolicy = ReportingPolicy.IGNORE
)
public interface ArtistMapper {

    ArtistDto toDto(String hash, String artistName);

    ArtistDto toDto(Artist artist);

    ArtistDetailDto toDetailDto(Artist artist);


    @Mapping(target = "songFileHashes", source = "songFileHashesCsv")
    ArtistExpandedDto toExpandedDto(ArtistListProjection projection);

    default List<String> mapSongFileHashes(String songFileHashesCsv) {
        if (songFileHashesCsv == null || songFileHashesCsv.isEmpty()) {
            return List.of();
        }
        return List.of(songFileHashesCsv.split(","));
    }
}
