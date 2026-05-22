package com.example.musicplayerbackend.mapper;

import static org.junit.jupiter.api.Assertions.*;

import com.example.musicplayerbackend.domain.NegotiationResponseDto;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.junit.jupiter.SpringExtension;

@ExtendWith(SpringExtension.class)
@Import(NegotiationMapperImpl.class)
class NegotiationMapperTest {

  @Autowired NegotiationMapper negotiationMapper;

  @Test
  void shouldMapFileHashAndMissingIndicesToNegotiationResponseDto() {
    NegotiationResponseDto dto =
        negotiationMapper.toNegotiationResponseDto("hash-42", List.of(1, 3, 5));

    assertEquals("hash-42", dto.getFileHash());
    assertEquals(List.of(1, 3, 5), dto.getMissingIndices());
  }

  @Test
  void shouldMapEmptyMissingIndicesToNegotiationResponseDto() {
    NegotiationResponseDto dto = negotiationMapper.toNegotiationResponseDto("hash-1", List.of());

    assertEquals("hash-1", dto.getFileHash());
    assertTrue(dto.getMissingIndices().isEmpty());
  }

  @Test
  void shouldReturnNullWhenBothNegotiationArgumentsAreNull() {
    NegotiationResponseDto dto = negotiationMapper.toNegotiationResponseDto(null, null);

    assertNull(dto);
  }

  @Test
  void shouldStillCreateNegotiationResponseDtoWhenFileHashIsNull() {
    NegotiationResponseDto dto = negotiationMapper.toNegotiationResponseDto(null, List.of(0));

    assertNotNull(dto);
    assertNull(dto.getFileHash());
    assertEquals(List.of(0), dto.getMissingIndices());
  }

  @Test
  void shouldNotSetMissingIndicesListWhenNullInNegotiationResponseDto() {
    NegotiationResponseDto dto = negotiationMapper.toNegotiationResponseDto("hash-99", null);

    assertNotNull(dto);
    assertEquals("hash-99", dto.getFileHash());
  }
}
