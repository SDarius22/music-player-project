package com.example.musicplayerbackend.mapper;

import org.mapstruct.Mapper;
import org.mapstruct.MappingConstants;
import org.mapstruct.ReportingPolicy;
import org.springframework.data.domain.Sort;

@Mapper(
    componentModel = MappingConstants.ComponentModel.SPRING,
    unmappedTargetPolicy = ReportingPolicy.IGNORE)
public interface SortMapper {

  default Sort toSort(String sort) {
    if (sort == null || sort.isBlank()) return Sort.by(Sort.Order.asc("name"));
    String[] parts = sort.split(",", 2);
    String dir = parts.length > 1 ? parts[1].trim() : "asc";
    return "desc".equals(dir) ? Sort.by(Sort.Order.desc("name")) : Sort.by(Sort.Order.asc("name"));
  }
}
