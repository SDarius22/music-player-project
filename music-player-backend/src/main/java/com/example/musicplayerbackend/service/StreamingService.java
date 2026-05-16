package com.example.musicplayerbackend.service;

import com.example.musicplayerbackend.data.SongRepository;
import com.example.musicplayerbackend.domain.Chunk;
import com.example.musicplayerbackend.domain.ChunkManifestDto;
import com.example.musicplayerbackend.domain.Song;
import com.example.musicplayerbackend.domain.SongChunk;
import lombok.RequiredArgsConstructor;
import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.io.File;
import java.util.ArrayList;
import java.util.List;

@Service
@RequiredArgsConstructor
public class StreamingService {

    private final SongRepository songRepository;

    @Transactional(readOnly = true)
    public ChunkManifestDto getSongManifest(String fileHash, Long userId) {
        Song song = getSongOrThrow(fileHash);
        if (song.getOwnerId() != null && !song.getOwnerId().equals(userId)) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Song not found");
        }

        List<String> hashes = new ArrayList<>();
        long totalBytes = 0;

        for (SongChunk sc : song.getChunks()) {
            hashes.add(sc.getChunk().getContentHash());
            totalBytes += sc.getChunk().getSize();
        }

        ChunkManifestDto manifest = new ChunkManifestDto();
        manifest.setFileHash(fileHash);
        manifest.setChunkSize(65536);
        manifest.setTotalChunks(hashes.size());
        manifest.setHashes(hashes);
        manifest.setTotalBytes(totalBytes);

        return manifest;
    }

    @Transactional(readOnly = true)
    public Resource getSongChunk(String fileHash, Integer chunkIndex, Long userId) {
        Song song = getSongOrThrow(fileHash);

        if (song.getOwnerId() != null && !song.getOwnerId().equals(userId)) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Song not found");
        }

        if (chunkIndex < 0 || chunkIndex >= song.getChunks().size()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Chunk index out of bounds");
        }

        SongChunk songChunk = song.getChunks().get(chunkIndex);
        Chunk physicalChunk = songChunk.getChunk();

        return readBytesFromDisk(physicalChunk.getStoragePath());
    }

    private Song getSongOrThrow(String fileHash) {
        return songRepository.findByFileHash(fileHash)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Song not found"));
    }

    private Resource readBytesFromDisk(String path) {
        File file = new File(path);
        if (!file.exists()) {
            throw new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR, "Physical chunk missing: " + path);
        }
        return new FileSystemResource(file);
    }
}
