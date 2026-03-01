package com.example.musicplayerbackend.service;

import com.example.musicplayerbackend.data.SongRepository;
import com.example.musicplayerbackend.domain.Song;
import com.example.musicplayerbackend.domain.SongSyncDto;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class DataSyncService {

    private final SongRepository songRepository;

    @Transactional
    public void syncOfflineData(List<SongSyncDto> syncRequests) {
        if (syncRequests == null || syncRequests.isEmpty()) {
            return;
        }

        // 1. Extract all requested IDs
        List<Integer> songIds = syncRequests.stream()
                .map(SongSyncDto::getSongId)
                .toList();

        // 2. Fetch all matching songs from the database in a single query
        Map<Integer, Song> databaseSongs = songRepository.findAllById(songIds).stream()
                .collect(Collectors.toMap(Song::getId, Function.identity()));

        // 3. Apply conflict resolution rules
        for (SongSyncDto request : syncRequests) {
            Song dbSong = databaseSongs.get(request.getSongId());

            if (dbSong == null) {
                // If the song doesn't exist on the master server anymore, drop the sync request.
                continue;
            }

            // Convert OpenAPI OffsetDateTime to our database Instant
            Instant requestLastPlayed = mapToInstant(request.getLastPlayed());
            Instant dbLastPlayed = dbSong.getLastPlayed();

            // RULE A: Additive Play Count (Deltas prevent lost offline plays)
            if (request.getPlayCountDelta() != null && request.getPlayCountDelta() > 0) {
                dbSong.setPlayCount(dbSong.getPlayCount() + request.getPlayCountDelta());
            }

            // RULE B: Last-Write-Wins (LWW) for State & Timestamps
            // We only apply the client's 'likedByUser' state if the client's action is strictly newer
            // than what the backend already knows about.
            if (requestLastPlayed != null) {
                if (dbLastPlayed == null || requestLastPlayed.isAfter(dbLastPlayed)) {
                    dbSong.setLastPlayed(requestLastPlayed);
                    dbSong.setLikedByUser(request.getLikedByUser());
                }
            }
        }

        // 4. Save the resolved entities back to the database
        // Spring Data JPA optimizes this into a batch update via Hibernate
        songRepository.saveAll(databaseSongs.values());
    }

    private Instant mapToInstant(OffsetDateTime offsetDateTime) {
        if (offsetDateTime == null) {
            return null;
        }
        return offsetDateTime.toInstant();
    }
}