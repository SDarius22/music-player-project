package com.example.musicplayerbackend.controller;

import com.example.musicplayerbackend.domain.NegotiationRequestDto;
import com.example.musicplayerbackend.domain.NegotiationResponseDto;
import com.example.musicplayerbackend.domain.SongDto;
import com.example.musicplayerbackend.domain.User;
import com.example.musicplayerbackend.service.SongService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;
import java.util.Objects;

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
    public ResponseEntity<NegotiationResponseDto> negotiateUserUpload(NegotiationRequestDto negotiationRequestDto) {
        User user = (User) Objects.requireNonNull(SecurityContextHolder.getContext().getAuthentication()).getPrincipal();
        return ResponseEntity.ok(songService.initiateNegotiation(negotiationRequestDto, Objects.requireNonNull(user).getId()));
    }

    @Override
    public ResponseEntity<Void> uploadMissingChunk(Long songId, Integer chunkIndex, MultipartFile chunkData, String contentHash) {
        User user = (User) Objects.requireNonNull(SecurityContextHolder.getContext().getAuthentication()).getPrincipal();
        try {
            songService.saveMissingChunk(user, songId, chunkIndex, contentHash, chunkData);
            return ResponseEntity.status(HttpStatus.CREATED).build();
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().build();
        }
    }

    @Override
    public ResponseEntity<Void> uploadSong(MultipartFile file, String name, String artistName, String albumName, Integer durationInSeconds, Integer trackNumber, Integer releaseYear, Integer discNumber, String photo) {
        try {
            songService.uploadSong(name, artistName, albumName, photo, durationInSeconds, trackNumber, discNumber, releaseYear, file);
            return ResponseEntity.status(HttpStatus.CREATED).build();
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().build();
        }
    }
}