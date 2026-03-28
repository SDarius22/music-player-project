package com.example.musicplayerbackend.mapper;

import com.example.musicplayerbackend.domain.NegotiationResponseDto;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.junit.jupiter.SpringExtension;

import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

@ExtendWith(SpringExtension.class)
@Import(NegotiationMapperImpl.class)
class NegotiationMapperTest {

    @Autowired NegotiationMapper negotiationMapper;

    @Test
    void shouldMapSongIdAndMissingIndicesToNegotiationResponseDto() {
        NegotiationResponseDto dto = negotiationMapper.toNegotiationResponseDto(42L, List.of(1, 3, 5));

        assertEquals(42L, dto.getSongId());
        assertEquals(List.of(1, 3, 5), dto.getMissingIndices());
    }

    @Test
    void shouldMapEmptyMissingIndicesToNegotiationResponseDto() {
        NegotiationResponseDto dto = negotiationMapper.toNegotiationResponseDto(1L, List.of());

        assertEquals(1L, dto.getSongId());
        assertTrue(dto.getMissingIndices().isEmpty());
    }

    @Test
    void shouldReturnNullWhenBothNegotiationArgumentsAreNull() {
        NegotiationResponseDto dto = negotiationMapper.toNegotiationResponseDto(null, null);

        assertNull(dto);
    }

    @Test
    void shouldStillCreateNegotiationResponseDtoWhenSongIdIsNull() {
        NegotiationResponseDto dto = negotiationMapper.toNegotiationResponseDto(null, List.of(0));

        assertNotNull(dto);
        assertNull(dto.getSongId());
        assertEquals(List.of(0), dto.getMissingIndices());
    }

    @Test
    void shouldNotSetMissingIndicesListWhenNullInNegotiationResponseDto() {
        NegotiationResponseDto dto = negotiationMapper.toNegotiationResponseDto(99L, null);

        assertNotNull(dto);
        assertEquals(99L, dto.getSongId());
    }
}
