package com.example.musicplayerbackend.service;

import com.example.musicplayerbackend.data.SongRepository;
import com.example.musicplayerbackend.data.UserLibraryRepository;
import com.example.musicplayerbackend.domain.*;
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

    private final UserLibraryRepository userLibraryRepository;
    private final SongRepository songRepository;

    @Transactional
    public void syncUserLibrary(User user, List<SongSyncDto> syncRequests) {
        if (syncRequests == null || syncRequests.isEmpty()) {
            return;
        }

        List<Long> songIds = syncRequests.stream().map(SongSyncDto::getSongId).toList();
        Map<Long, Song> songs = songRepository.findAllById(songIds).stream()
                .collect(Collectors.toMap(Song::getId, Function.identity()));

        for (SongSyncDto request : syncRequests) {
            Song song = songs.get(request.getSongId());
            if (song == null) continue;

            UserLibraryID id = new UserLibraryID(user.getId(), request.getSongId());

            UserLibrary libEntry = userLibraryRepository.findById(id)
                    .orElseGet(() -> UserLibrary.builder()
                            .id(id)
                            .song(song)
                            .user(user)
                            .addedAt(Instant.now())
                            .playCount(0L)
                            .liked(false)
                            .build());

            resolveConflicts(libEntry, request);
            userLibraryRepository.save(libEntry);
        }
    }

    private void resolveConflicts(UserLibrary dbEntry, SongSyncDto request) {
        Instant requestLastPlayed = mapToInstant(request.getLastPlayed());
        Instant dbLastPlayed = dbEntry.getLastPlayed();

        if (request.getPlayCountDelta() != null && request.getPlayCountDelta() > 0) {
            dbEntry.setPlayCount(dbEntry.getPlayCount() + request.getPlayCountDelta());
        }

        if (requestLastPlayed != null) {
            if (dbLastPlayed == null || requestLastPlayed.isAfter(dbLastPlayed)) {
                dbEntry.setLastPlayed(requestLastPlayed);
                dbEntry.setLiked(request.getLikedByUser());
            }
        }
    }

    private Instant mapToInstant(OffsetDateTime offsetDateTime) {
        return offsetDateTime == null ? null : offsetDateTime.toInstant();
    }
}