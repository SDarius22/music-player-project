package com.example.musicplayerbackend.mapper;

import com.example.musicplayerbackend.domain.NegotiationResponseDto;
import java.util.List;
import org.mapstruct.Mapper;
import org.mapstruct.MappingConstants;
import org.mapstruct.ReportingPolicy;

@Mapper(
    componentModel = MappingConstants.ComponentModel.SPRING,
    unmappedTargetPolicy = ReportingPolicy.IGNORE)
public interface NegotiationMapper {
  NegotiationResponseDto toNegotiationResponseDto(String fileHash, List<Integer> missingIndices);
}
