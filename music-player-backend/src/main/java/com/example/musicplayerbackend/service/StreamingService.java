package com.example.musicplayerbackend.service;

import com.example.musicplayerbackend.data.SongRepository;
import com.example.musicplayerbackend.domain.Song;
import lombok.RequiredArgsConstructor;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.io.File;
import java.io.IOException;
import java.io.RandomAccessFile;
import java.util.List;

@Service
@RequiredArgsConstructor
public class StreamingService {

    private final SongRepository songRepository;

    @Transactional(readOnly = true)
    public List<Integer> getPredictivePrefetchList(String userId) {
        // Fetch the top 10 most played songs across the network
        return songRepository.findTopPlayedSongIds(PageRequest.of(0, 10));
    }

    @Transactional(readOnly = true)
    public Resource getSongPrefix(Integer songId, Integer prefixBytes) {
        Song song = songRepository.findById(songId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Song metadata not found"));

        File audioFile = new File(song.getPath());
        if (!audioFile.exists()) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Audio file missing from disk");
        }

        int bytesToRead = (prefixBytes != null && prefixBytes > 0) ? prefixBytes : 512000;
        bytesToRead = (int) Math.min(bytesToRead, audioFile.length());

        byte[] buffer = new byte[bytesToRead];

        try (RandomAccessFile raf = new RandomAccessFile(audioFile, "r")) {
            raf.readFully(buffer);
            return new ByteArrayResource(buffer);
        } catch (IOException e) {
            throw new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR, "Failed to read audio file prefix");
        }
    }

    @Transactional(readOnly = true)
    public Resource getFullStream(Integer songId) {
        Song song = songRepository.findById(songId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Song metadata not found"));

        File audioFile = new File(song.getPath());
        if (!audioFile.exists()) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Audio file missing from disk");
        }

        return new FileSystemResource(audioFile);
    }
}