package com.example.musicplayerbackend.service;

import com.example.musicplayerbackend.data.SongRepository;
import com.example.musicplayerbackend.domain.ChunkManifestDto;
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
import java.io.FileInputStream;
import java.io.IOException;
import java.io.RandomAccessFile;
import java.security.MessageDigest;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@Service
@RequiredArgsConstructor
public class StreamingService {

    private static final int CHUNK_SIZE = 262144;

    // In-memory cache so we only calculate the SHA-256 hashes once per song
    private final Map<Integer, ChunkManifestDto> manifestCache = new ConcurrentHashMap<>();

    private final SongRepository songRepository;

    @Transactional(readOnly = true)
    public ChunkManifestDto getSongManifest(Integer songId) {
        return manifestCache.computeIfAbsent(songId, this::generateManifest);
    }

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

    private ChunkManifestDto generateManifest(Integer songId) {
        Song song = songRepository.findById(songId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Song not found"));

        File audioFile = new File(song.getPath());
        if (!audioFile.exists()) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "File missing from disk");
        }

        try (FileInputStream fis = new FileInputStream(audioFile)) {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            List<String> hashes = new ArrayList<>();
            byte[] buffer = new byte[CHUNK_SIZE];
            int bytesRead;

            while ((bytesRead = fis.read(buffer)) != -1) {
                digest.update(buffer, 0, bytesRead);
                byte[] hashBytes = digest.digest();

                // Convert byte array to Hex string
                StringBuilder hexString = new StringBuilder();
                for (byte b : hashBytes) {
                    hexString.append(String.format("%02x", b));
                }
                hashes.add(hexString.toString());
            }

            ChunkManifestDto manifest = new ChunkManifestDto();
            manifest.setSongId(songId);
            manifest.setChunkSize(CHUNK_SIZE);
            manifest.setTotalChunks(hashes.size());
            manifest.setHashes(hashes);

            return manifest;

        } catch (Exception e) {
            throw new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR, "Failed to generate chunk hashes");
        }
    }

    @Transactional(readOnly = true)
    public Resource getSongChunk(Integer songId, Integer chunkIndex) {
        Song song = songRepository.findById(songId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Song not found"));

        File audioFile = new File(song.getPath());
        if (!audioFile.exists()) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "File missing from disk");
        }

        try (RandomAccessFile raf = new RandomAccessFile(audioFile, "r")) {
            long startPosition = (long) chunkIndex * CHUNK_SIZE;
            if (startPosition >= raf.length()) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Chunk index out of bounds");
            }

            raf.seek(startPosition);
            int bytesToRead = (int) Math.min(CHUNK_SIZE, raf.length() - startPosition);
            byte[] buffer = new byte[bytesToRead];
            raf.readFully(buffer);

            return new ByteArrayResource(buffer);
        } catch (IOException e) {
            throw new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR, "Failed to read chunk");
        }
    }
}