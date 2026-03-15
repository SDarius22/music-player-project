package com.example.musicplayerbackend.controller;

import com.example.musicplayerbackend.domain.SyncRequestDto;
import com.example.musicplayerbackend.domain.SyncResponseDto;
import com.example.musicplayerbackend.domain.User;
import com.example.musicplayerbackend.service.DataSyncService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Objects;

@Slf4j
@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class DataSyncController implements SyncApi {

    private final DataSyncService dataSyncService;

    @Override
    public ResponseEntity<SyncResponseDto> syncUserLibrary(SyncRequestDto syncRequestDto) {
        User user = (User) Objects.requireNonNull(SecurityContextHolder.getContext().getAuthentication()).getPrincipal();

        log.info("[SYNC] Request from userId={}, lastSyncTime={}, localChanges={}",
                user.getId(),
                syncRequestDto.getLastSyncTime(),
                syncRequestDto.getLocalChanges() != null ? syncRequestDto.getLocalChanges().size() : 0);

        SyncResponseDto response = dataSyncService.performSync(user.getId(), syncRequestDto);
        log.info("[SYNC] Response to userId={}: serverChanges={}, hasMore={}, newSyncTime={}",
                user.getId(), response.getServerChanges().size(), response.getHasMore(), response.getNewSyncTime());

        return ResponseEntity.ok(response);
    }
}