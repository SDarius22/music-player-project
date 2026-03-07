package com.example.musicplayerbackend.controller;

import com.example.musicplayerbackend.domain.SongDto;
import com.example.musicplayerbackend.service.SongService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;

@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class SongController implements SongsApi {

    private final SongService songService;

    @Override
    public ResponseEntity<List<SongDto>> getAllSongs() {
        return ResponseEntity.ok(songService.getAllSongs());
    }

    @Override
    public ResponseEntity<SongDto> getSongById(Long songId) {
        return ResponseEntity.ok(songService.getSongById(songId));
    }

    @Override
    public ResponseEntity<Void> uploadSong(MultipartFile file, String name, String artistName, String albumName, Integer durationInSeconds, Integer trackNumber, Integer releaseYear) {
        try {
            songService.uploadSong(name, artistName, albumName, durationInSeconds, trackNumber, releaseYear, file);
            return ResponseEntity.status(HttpStatus.CREATED).build();
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().build();
        }
    }
}