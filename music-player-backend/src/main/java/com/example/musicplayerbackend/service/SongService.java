package com.example.musicplayerbackend.service;

import com.example.musicplayerbackend.data.*;
import com.example.musicplayerbackend.domain.*;
import com.example.musicplayerbackend.mapper.NegotiationMapper;
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
import java.util.Optional;

@Service
@RequiredArgsConstructor
public class SongService {

    private final SongRepository songRepository;
    private final ArtistRepository artistRepository;
    private final AlbumRepository albumRepository;
    private final ChunkRepository chunkRepository;
    private final SongChunkRepository songChunkRepository;
    private final SongMapper songMapper;
    private final NegotiationMapper negotiationMapper;

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
    public void uploadSong(String name, String artistName, String albumName, String photo,
                           Integer duration, Integer track, Integer disc, Integer year, MultipartFile file) throws Exception {

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
                .ownerId(null)
                .discNumber(disc)
                .photo(photo)
                .trackNumber(track)
                .releaseYear(year)
                .build();

        song = songRepository.save(song);

        processFileIntoChunks(file, song);
    }

    @Transactional
    public NegotiationResponseDto initiateNegotiation(NegotiationRequestDto request, Long userId) {
        Artist artist = artistRepository.findByName(request.getArtistName())
                .orElseGet(() -> artistRepository.save(Artist.builder().name(request.getArtistName()).build()));

        Album album = albumRepository.findByName(request.getAlbumName())
                .orElseGet(() -> albumRepository.save(Album.builder().name(request.getAlbumName()).build()));

        Song song = Song.builder()
                .name(request.getName())
                .artist(artist)
                .album(album)
                .songType(SongType.USER_UPLOAD)
                .ownerId(userId)
                .durationInSeconds(request.getDurationInSeconds())
                .trackNumber(request.getTrackNumber())
                .discNumber(request.getDiscNumber())
                .releaseYear(request.getReleaseYear())
                .photo(request.getPhoto())
                .build();

        song = songRepository.save(song);

        List<Integer> missingIndices = new ArrayList<>();
        List<SongChunk> existingLinks = new ArrayList<>();

        List<String> hashes = request.getHashes();
        for (int i = 0; i < hashes.size(); i++) {
            String hash = hashes.get(i);
            Optional<Chunk> existingChunk = chunkRepository.findByContentHash(hash);

            if (existingChunk.isPresent()) {
                existingLinks.add(SongChunk.builder()
                        .song(song)
                        .chunk(existingChunk.get())
                        .orderIndex(i)
                        .build());
            } else {
                missingIndices.add(i);
            }
        }

        songChunkRepository.saveAll(existingLinks);

        return negotiationMapper.toNegotiationResponseDto(song.getId(), missingIndices);
    }


    @Transactional
    public void saveMissingChunk(User user, Long songId, Integer chunkIndex, String contentHash, MultipartFile chunkFile) throws Exception {
        Song song = songRepository.findById(songId)
                .orElseThrow(() -> new RuntimeException("Song not found"));

        if (!song.getOwnerId().equals(user.getId())) {
            throw new RuntimeException("Unauthorized: You do not own this song.");
        }

        byte[] bytes = chunkFile.getBytes();

        String calculatedHash = bytesToHex(MessageDigest.getInstance("SHA-256").digest(bytes));
        if (!calculatedHash.equalsIgnoreCase(contentHash)) {
            throw new RuntimeException("Integrity Error: Client hash does not match server calculation.");
        }

        Chunk chunk = chunkRepository.findByContentHash(calculatedHash)
                .orElseGet(() -> {
                    try {
                        String path = STORAGE_ROOT + "/" + calculatedHash;
                        Files.createDirectories(Paths.get(STORAGE_ROOT));
                        try (FileOutputStream fos = new FileOutputStream(path)) {
                            fos.write(bytes);
                        }
                        return chunkRepository.save(Chunk.builder()
                                .contentHash(calculatedHash)
                                .size(bytes.length)
                                .storagePath(path)
                                .build());
                    } catch (Exception e) {
                        throw new RuntimeException("Storage failed", e);
                    }
                });

        boolean linkExists = song.getChunks().stream().anyMatch(sc -> sc.getOrderIndex().equals(chunkIndex));
        if (!linkExists) {
            SongChunk link = SongChunk.builder()
                    .song(song)
                    .chunk(chunk)
                    .orderIndex(chunkIndex)
                    .build();
            songChunkRepository.save(link);
        }
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