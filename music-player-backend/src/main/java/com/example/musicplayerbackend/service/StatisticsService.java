package com.example.musicplayerbackend.service;

import com.example.musicplayerbackend.data.ChunkStatRepository;
import com.example.musicplayerbackend.domain.ChunkStat;
import com.example.musicplayerbackend.domain.ChunkStatDto;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;

@Slf4j
@Service
@RequiredArgsConstructor
public class StatisticsService {

    private final ChunkStatRepository chunkStatRepository;

    @Transactional(readOnly = true)
    public List<ChunkStatDto> getAll() {
        return chunkStatRepository.findAll().stream()
                .map(this::toDto)
                .toList();
    }

    @Transactional
    public void record(ChunkStatDto dto, Long userId) {
        int local = dto.getLocalChunks() == null ? 0 : dto.getLocalChunks();
        int localCached = dto.getLocalCachedChunks() == null ? 0 : dto.getLocalCachedChunks();
        int p2p = dto.getP2pChunks() == null ? 0 : dto.getP2pChunks();
        int server = dto.getServerChunks() == null ? 0 : dto.getServerChunks();
        int total = local + localCached + p2p + server;
        double pct = total > 0 ? p2p * 100.0 / total : 0.0;

        ChunkStat stat = ChunkStat.builder()
                .timestamp(Instant.now())
                .userId(userId)
                .songFileHash(dto.getSongFileHash())
                .songName(dto.getSongName())
                .localChunks(local)
                .localCachedChunks(localCached)
                .p2pChunks(p2p)
                .serverChunks(server)
                .totalChunks(total)
                .p2pPercentage(pct)
                .build();

        chunkStatRepository.save(stat);
        log.debug("[STATS] Recorded chunk stat: userId={}, song='{}', local={}, cached={}, p2p={}%, total={}",
                userId, dto.getSongName(), local, localCached, String.format("%.1f", pct), total);
    }

    private ChunkStatDto toDto(ChunkStat stat) {
        ChunkStatDto dto = new ChunkStatDto();
        dto.setId(stat.getId());
        dto.setTimestamp(stat.getTimestamp() != null
                ? stat.getTimestamp().atOffset(java.time.ZoneOffset.UTC)
                : null);
        dto.setUserId(stat.getUserId());
        dto.setSongFileHash(stat.getSongFileHash());
        dto.setSongName(stat.getSongName());
        dto.setLocalChunks(stat.getLocalChunks());
        dto.setLocalCachedChunks(stat.getLocalCachedChunks());
        dto.setP2pChunks(stat.getP2pChunks());
        dto.setServerChunks(stat.getServerChunks());
        dto.setTotalChunks(stat.getTotalChunks());
        dto.setP2pPercentage(stat.getP2pPercentage());
        return dto;
    }
}
