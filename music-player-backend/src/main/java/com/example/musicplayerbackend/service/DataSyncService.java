package com.example.musicplayerbackend.service;

import com.example.musicplayerbackend.components.SignalingHandler;
import com.example.musicplayerbackend.data.SongRepository;
import com.example.musicplayerbackend.data.UserLibraryRepository;
import com.example.musicplayerbackend.data.UserRepository;
import com.example.musicplayerbackend.domain.*;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class DataSyncService {

    private final UserLibraryRepository userLibraryRepository;
    private final SongRepository songRepository;
    private final UserRepository userRepository;
    private final SignalingHandler signalingHandler;

    @Transactional
    public SyncResponseDto performSync(Long userId, SyncRequestDto request) {
        Instant now = Instant.now();

        if (request.getLocalChanges() != null && !request.getLocalChanges().isEmpty()) {
            applyClientChanges(userId, request.getLocalChanges(), now);

            signalingHandler.sendSyncTrigger(userId);
        }

        List<UserLibrary> serverChanges;

        if (request.getLastSyncTime() == null) {
            serverChanges = userLibraryRepository.findByIdUserIdAndIsDeletedFalse(userId);
        } else {
            Instant lastSync = request.getLastSyncTime().toInstant();
            serverChanges = userLibraryRepository.findByIdUserIdAndLastUpdatedAfter(userId, lastSync);
        }

        List<SongSyncDto> dtos = serverChanges.stream()
                .map(this::mapEntityToDto)
                .collect(Collectors.toList());

        SyncResponseDto response = new SyncResponseDto();
        response.setNewSyncTime(OffsetDateTime.ofInstant(now, ZoneOffset.UTC));
        response.setServerChanges(dtos);

        return response;
    }

    private void applyClientChanges(Long userId, List<SongSyncDto> changes, Instant now) {
        User userReference = userRepository.getReferenceById(userId);

        for (SongSyncDto change : changes) {
            UserLibraryID id = new UserLibraryID(userId, change.getSongId());

            UserLibrary libEntry = userLibraryRepository.findById(id)
                    .orElseGet(() -> {
                        Song song = songRepository.findById(change.getSongId()).orElse(null);
                        if (song == null) return null;

                        return UserLibrary.builder()
                                .id(id)
                                .user(userReference)
                                .song(song)
                                .playCount(0L)
                                .liked(false)
                                .isDeleted(false)
                                .isDownloadedLocally(false)
                                .lastUpdated(now)
                                .build();
                    });

            if (libEntry == null) continue;

            if (Boolean.TRUE.equals(change.getIsDeleted())) {
                libEntry.setIsDeleted(true);
            } else {
                libEntry.setIsDeleted(false);

                if (change.getLikedByUser() != null) {
                    libEntry.setLiked(change.getLikedByUser());
                }
                if (change.getPlayCountDelta() != null && change.getPlayCountDelta() > 0) {
                    libEntry.setPlayCount(libEntry.getPlayCount() + change.getPlayCountDelta());
                }
                if (change.getLastPlayed() != null) {
                    libEntry.setLastPlayed(change.getLastPlayed().toInstant());
                }
                if (change.getAddedAt() != null) {
                    libEntry.setAddedAt(change.getAddedAt().toInstant());
                }
            }

            libEntry.setLastUpdated(now);
            userLibraryRepository.save(libEntry);
        }
    }

    private SongSyncDto mapEntityToDto(UserLibrary entity) {
        SongSyncDto dto = new SongSyncDto();
        if (entity.getSong() != null) {
            dto.setSongId(entity.getSong().getId());
        }

        dto.setLikedByUser(entity.getLiked());
        dto.setIsDeleted(entity.getIsDeleted());
        dto.setPlayCountDelta(0);

        if (entity.getLastPlayed() != null) {
            dto.setLastPlayed(OffsetDateTime.ofInstant(entity.getLastPlayed(), ZoneOffset.UTC));
        }
        if (entity.getAddedAt() != null) {
            dto.setAddedAt(OffsetDateTime.ofInstant(entity.getAddedAt(), ZoneOffset.UTC));
        }
        return dto;
    }
}