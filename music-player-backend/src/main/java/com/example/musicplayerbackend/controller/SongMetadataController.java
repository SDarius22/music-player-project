package com.example.musicplayerbackend.controller;

import com.example.musicplayerbackend.domain.SongDto;
import com.example.musicplayerbackend.service.SongMetadataService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class SongMetadataController implements SongsApi {

    private final SongMetadataService songMetadataService;

    @Override
    public ResponseEntity<List<SongDto>> getAllSongs() {
        return ResponseEntity.ok(songMetadataService.getAllSongs());
    }
}