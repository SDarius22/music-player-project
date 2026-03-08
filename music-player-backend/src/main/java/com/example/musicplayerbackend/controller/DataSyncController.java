package com.example.musicplayerbackend.controller;

import com.example.musicplayerbackend.domain.SyncRequestDto;
import com.example.musicplayerbackend.domain.SyncResponseDto;
import com.example.musicplayerbackend.domain.User;
import com.example.musicplayerbackend.service.DataSyncService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Objects;

@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class DataSyncController implements SyncApi {

    private final DataSyncService dataSyncService;

    @Override
    public ResponseEntity<SyncResponseDto> syncUserLibrary(SyncRequestDto syncRequestDto) {
        User user = (User) Objects.requireNonNull(SecurityContextHolder.getContext().getAuthentication()).getPrincipal();

        SyncResponseDto response = dataSyncService.performSync(user.getId(), syncRequestDto);

        return ResponseEntity.ok(response);
    }
}