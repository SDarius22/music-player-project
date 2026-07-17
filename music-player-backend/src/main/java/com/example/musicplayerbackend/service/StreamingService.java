package com.example.musicplayerbackend.service;

import com.example.musicplayerbackend.data.SongChunkRepository;
import com.example.musicplayerbackend.data.SongRepository;
import com.example.musicplayerbackend.domain.ChunkManifestDto;
import com.example.musicplayerbackend.domain.Song;
import com.example.musicplayerbackend.domain.SongChunk;
import com.example.musicplayerbackend.domain.Role;
import com.example.musicplayerbackend.domain.User;
import java.io.File;
import java.util.ArrayList;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@Service
@RequiredArgsConstructor
public class StreamingService {

  private final SongRepository songRepository;
  private final SongChunkRepository songChunkRepository;

  @Transactional(readOnly = true)
  public ChunkManifestDto getSongManifest(String fileHash, User user) {
    Song song = getSongOrThrow(fileHash);
    ensureSongVisible(song, user);

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
  public Resource getSongChunk(String fileHash, Integer chunkIndex, User user) {
    Song song = getSongOrThrow(fileHash);
    ensureSongVisible(song, user);

    if (chunkIndex == null || chunkIndex < 0) {
      throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Chunk index out of bounds");
    }

    SongChunk songChunk =
        songChunkRepository
            .findWithChunkBySongAndOrderIndex(song, chunkIndex)
            .orElseThrow(
                () ->
                    new ResponseStatusException(
                        HttpStatus.BAD_REQUEST, "Chunk index out of bounds"));

    return readBytesFromDisk(songChunk.getChunk().getStoragePath());
  }

  private Song getSongOrThrow(String fileHash) {
    return songRepository
        .findByFileHash(fileHash)
        .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Song not found"));
  }

  private void ensureSongVisible(Song song, User user) {
    boolean owned = java.util.Objects.equals(song.getOwnerId(), user.getId());
    boolean mayAccessPublic = user.isAllowed() || user.getRole() == Role.ADMIN;
    if (!owned && !(song.getOwnerId() == null && mayAccessPublic)) {
      throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Song not found");
    }
  }

  private Resource readBytesFromDisk(String path) {
    File file = new File(path);
    if (!file.exists()) {
      throw new ResponseStatusException(
          HttpStatus.INTERNAL_SERVER_ERROR, "Physical chunk missing: " + path);
    }
    return new FileSystemResource(file);
  }
}
