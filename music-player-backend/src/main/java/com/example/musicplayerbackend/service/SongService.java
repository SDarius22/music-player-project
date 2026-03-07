package com.example.musicplayerbackend.service;

import com.example.musicplayerbackend.data.*;
import com.example.musicplayerbackend.domain.*;
import com.example.musicplayerbackend.mapper.SongMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.FileOutputStream;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.security.MessageDigest;
import java.util.ArrayList;
import java.util.List;

@Service
@RequiredArgsConstructor
public class SongService {

    private final SongRepository songRepository;
    private final ArtistRepository artistRepository;
    private final AlbumRepository albumRepository;
    private final ChunkRepository chunkRepository;
    private final SongChunkRepository songChunkRepository;
    private final SongMapper songMapper;

    private final String STORAGE_ROOT = System.getProperty("user.home") + "/music-server/chunks";

    @Transactional(readOnly = true)
    public List<SongDto> getAllSongs() {
        return songRepository.findAll()
                .stream()
                .map(songMapper::toDto)
                .toList();
    }

    @Transactional(readOnly = true)
    public SongDto getSongById(Long songId) {
        return songRepository.findById(songId)
                .map(songMapper::toDto)
                .orElseThrow(() -> new RuntimeException("Song not found with id: " + songId));
    }


    @Transactional
    public void uploadSong(String name, String artistName, String albumName,
                           Integer duration, Integer track, Integer year, MultipartFile file) throws Exception {

        Artist artist = artistRepository.findByName(artistName)
                .orElseGet(() -> artistRepository.save(Artist.builder().name(artistName).build()));

        Album album = albumRepository.findByName(albumName)
                .orElseGet(() -> albumRepository.save(Album.builder().name(albumName).build()));

        Song song = Song.builder()
                .name(name)
                .artist(artist)
                .album(album)
                .songType(SongType.STREAMABLE)
                .durationInSeconds(duration)
                .trackNumber(track)
                .releaseYear(year)
                .build();

        song = songRepository.save(song);

        processFileIntoChunks(file, song);
    }

    private void processFileIntoChunks(MultipartFile file, Song song) throws Exception {
        InputStream is = file.getInputStream();
        byte[] buffer = new byte[65536]; // 64KB
        int bytesRead;
        int orderIndex = 0;

        MessageDigest digest = MessageDigest.getInstance("SHA-256");
        Files.createDirectories(Paths.get(STORAGE_ROOT));
        List<SongChunk> songChunks = new ArrayList<>();

        while ((bytesRead = is.read(buffer)) != -1) {
            digest.reset();
            digest.update(buffer, 0, bytesRead);
            String hash = bytesToHex(digest.digest());

            Chunk chunk = chunkRepository.findByContentHash(hash).orElse(null);

            if (chunk == null) {
                String storagePath = STORAGE_ROOT + "/" + hash;
                try (FileOutputStream fos = new FileOutputStream(storagePath)) {
                    fos.write(buffer, 0, bytesRead);
                }
                chunk = Chunk.builder()
                        .contentHash(hash)
                        .size(bytesRead)
                        .storagePath(storagePath)
                        .build();
                chunk = chunkRepository.save(chunk);
            }

            SongChunk link = SongChunk.builder()
                    .song(song)
                    .chunk(chunk)
                    .orderIndex(orderIndex++)
                    .build();
            songChunks.add(link);
        }
        songChunkRepository.saveAll(songChunks);
    }

    private String bytesToHex(byte[] hash) {
        StringBuilder hex = new StringBuilder(2 * hash.length);
        for (byte b : hash) {
            String h = Integer.toHexString(0xff & b);
            if (h.length() == 1) hex.append('0');
            hex.append(h);
        }
        return hex.toString();
    }
}