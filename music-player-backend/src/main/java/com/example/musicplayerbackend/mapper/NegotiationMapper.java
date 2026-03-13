package com.example.musicplayerbackend.mapper;

import com.example.musicplayerbackend.domain.NegotiationResponseDto;
import org.mapstruct.Mapper;
import org.mapstruct.MappingConstants;
import org.mapstruct.ReportingPolicy;

import java.util.List;

@Mapper(
        componentModel = MappingConstants.ComponentModel.SPRING,
        unmappedTargetPolicy = ReportingPolicy.IGNORE
)
public interface NegotiationMapper {
    NegotiationResponseDto toNegotiationResponseDto(Long songId, List<Integer> missingIndices);
}
