package com.example.musicplayerbackend.controller;

import com.example.musicplayerbackend.domain.SongSyncDto;
import com.example.musicplayerbackend.service.DataSyncService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequiredArgsConstructor
public class DataSyncController implements SyncApi {

    private final DataSyncService dataSyncService;

    @Override
    public ResponseEntity<Void> syncOfflineData(List<SongSyncDto> songSyncDto) {
        dataSyncService.syncOfflineData(songSyncDto);
        return ResponseEntity.ok().build();
    }
}