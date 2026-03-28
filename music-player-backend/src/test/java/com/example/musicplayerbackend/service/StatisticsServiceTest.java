package com.example.musicplayerbackend.service;

import com.example.musicplayerbackend.data.ChunkStatRepository;
import com.example.musicplayerbackend.domain.ChunkStat;
import com.example.musicplayerbackend.domain.ChunkStatDto;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Captor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class StatisticsServiceTest {

    @Mock
    ChunkStatRepository chunkStatRepository;
    @Captor
    ArgumentCaptor<ChunkStat> statCaptor;

    StatisticsService service;

    @BeforeEach
    void setUp() {
        service = new StatisticsService(chunkStatRepository);
    }

    @Test
    void shouldReturnAllStatsAsDtos() {
        ChunkStat stat = ChunkStat.builder()
                .id(1L).userId(10L).songId(20L).songName("Test Song")
                .p2pChunks(8).serverChunks(2).totalChunks(10)
                .p2pPercentage(80.0).timestamp(Instant.now())
                .build();
        when(chunkStatRepository.findAll()).thenReturn(List.of(stat));

        List<ChunkStatDto> result = service.getAll();

        assertEquals(1, result.size());
        ChunkStatDto dto = result.getFirst();
        assertEquals(1L, dto.getId());
        assertEquals(10L, dto.getUserId());
        assertEquals(20L, dto.getSongId());
        assertEquals("Test Song", dto.getSongName());
        assertEquals(8, dto.getP2pChunks());
        assertEquals(2, dto.getServerChunks());
        assertEquals(10, dto.getTotalChunks());
        assertEquals(80.0, dto.getP2pPercentage());
        assertNotNull(dto.getTimestamp());
    }

    @Test
    void shouldMapNullTimestampToNull() {
        ChunkStat stat = ChunkStat.builder()
                .id(2L).userId(1L).songId(1L).songName("No Time")
                .p2pChunks(0).serverChunks(0).totalChunks(0)
                .p2pPercentage(0.0).timestamp(null) // null timestamp
                .build();
        when(chunkStatRepository.findAll()).thenReturn(List.of(stat));

        List<ChunkStatDto> result = service.getAll();

        assertNull(result.getFirst().getTimestamp());
    }

    @Test
    void shouldReturnEmptyStatsListWhenNoneExist() {
        when(chunkStatRepository.findAll()).thenReturn(List.of());
        assertTrue(service.getAll().isEmpty());
    }

    @Test
    void shouldCalculateP2pPercentageCorrectly() {
        ChunkStatDto dto = new ChunkStatDto();
        dto.setSongId(1L);
        dto.setSongName("Song A");
        dto.setP2pChunks(7);
        dto.setServerChunks(3);

        service.record(dto, 42L);

        verify(chunkStatRepository).save(statCaptor.capture());
        ChunkStat saved = statCaptor.getValue();
        assertEquals(42L, saved.getUserId());
        assertEquals(10, saved.getTotalChunks());
        assertEquals(70.0, saved.getP2pPercentage(), 0.001);
    }

    @Test
    void shouldCalculateZeroP2pPercentageWhenAllChunksFromServer() {
        ChunkStatDto dto = new ChunkStatDto();
        dto.setP2pChunks(0);
        dto.setServerChunks(10);

        service.record(dto, 1L);

        verify(chunkStatRepository).save(statCaptor.capture());
        assertEquals(0.0, statCaptor.getValue().getP2pPercentage());
    }

    @Test
    void shouldUseServerChunksOnlyWhenP2pChunksIsNull() {
        ChunkStatDto dto = new ChunkStatDto();
        dto.setP2pChunks(null);
        dto.setServerChunks(10);

        service.record(dto, 1L);

        verify(chunkStatRepository).save(statCaptor.capture());
        ChunkStat saved = statCaptor.getValue();
        assertEquals(0, saved.getP2pChunks());
        assertEquals(10, saved.getServerChunks());
        assertEquals(10, saved.getTotalChunks());
        assertEquals(0.0, saved.getP2pPercentage());
    }

    @Test
    void shouldUse100PercentWhenServerChunksIsNull() {
        ChunkStatDto dto = new ChunkStatDto();
        dto.setP2pChunks(8);
        dto.setServerChunks(null);

        service.record(dto, 1L);

        verify(chunkStatRepository).save(statCaptor.capture());
        ChunkStat saved = statCaptor.getValue();
        assertEquals(8, saved.getP2pChunks());
        assertEquals(0, saved.getServerChunks());
        assertEquals(8, saved.getTotalChunks());
        assertEquals(100.0, saved.getP2pPercentage(), 0.001);
    }

    @Test
    void shouldHandleNullChunkCounts() {
        ChunkStatDto dto = new ChunkStatDto();
        dto.setP2pChunks(null);
        dto.setServerChunks(null);

        service.record(dto, 1L);

        verify(chunkStatRepository).save(statCaptor.capture());
        ChunkStat saved = statCaptor.getValue();
        assertEquals(0, saved.getP2pChunks());
        assertEquals(0, saved.getServerChunks());
        assertEquals(0, saved.getTotalChunks());
        assertEquals(0.0, saved.getP2pPercentage());
    }

    @Test
    void shouldSetTotalChunksAndTimestamp() {
        ChunkStatDto dto = new ChunkStatDto();
        dto.setP2pChunks(4);
        dto.setServerChunks(6);

        Instant before = Instant.now();
        service.record(dto, 1L);
        Instant after = Instant.now();

        verify(chunkStatRepository).save(statCaptor.capture());
        ChunkStat saved = statCaptor.getValue();
        assertEquals(10, saved.getTotalChunks());
        assertFalse(saved.getTimestamp().isBefore(before));
        assertFalse(saved.getTimestamp().isAfter(after));
    }
}
