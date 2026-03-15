package com.example.musicplayerbackend.service;

import com.example.musicplayerbackend.data.*;
import com.example.musicplayerbackend.domain.*;
import com.example.musicplayerbackend.mapper.NegotiationMapper;
import com.example.musicplayerbackend.mapper.SongMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
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
import java.util.Objects;
import java.util.Optional;

@Slf4j
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
    public Page<SongDto> getSongsVisibleToUser(String q, User user, Pageable pageable) {
        Specification<Song> spec = SongSpecifications.visibleTo(user.getId());
        Specification<Song> qSpec = SongSpecifications.matchesQuery(q);
        if (qSpec != null) {
            spec = spec.and(qSpec);
        }

        return songRepository.findAll(spec, pageable)
                .map(songMapper::toDto);
    }

    @Transactional(readOnly = true)
    public SongDto getSongById(Long songId) {
        return songRepository.findById(songId)
                .map(songMapper::toDto)
                .orElseThrow(() -> new RuntimeException("Song not found with id: " + songId));
    }


    @Transactional
    public void uploadSong(User user, String name, String artistName, String albumName, String photo,
                           Integer duration, Integer track, Integer disc, Integer year, MultipartFile file, String fileHash) throws Exception {
        if (user.getAuthorities().stream().noneMatch(auth -> Objects.equals(auth.getAuthority(), "ROLE_ADMIN"))) {
            throw new RuntimeException("Unauthorized: Only admins can upload songs.");
        }
        Song existingSong = songRepository.findByFileHash(fileHash).orElse(null);
        if (existingSong != null) {
            log.info("[SONG] Duplicate detected for fileHash={} — promoting existing song id={} to STREAMABLE", fileHash, existingSong.getId());
            existingSong.setOwnerId(null);
            existingSong.setSongType(SongType.STREAMABLE);
            songRepository.save(existingSong);
            return;
        }

        Artist artist = artistRepository.findByName(artistName)
                .orElseGet(() -> artistRepository.save(Artist.builder().name(artistName).build()));

        Album album = albumRepository.findByName(albumName)
                .orElseGet(() -> albumRepository.save(
                        Album.builder()
                                .name(albumName)
                                .coverImage(photo)
                                .build()));

        Song song = Song.builder()
                .name(name)
                .artist(artist)
                .album(album)
                .songType(SongType.STREAMABLE)
                .durationInSeconds(duration)
                .ownerId(null)
                .discNumber(disc)
                .trackNumber(track)
                .releaseYear(year)
                .fileHash(fileHash)
                .build();

        song = songRepository.save(song);
        log.info("[SONG] Saved new song: id={}, name='{}', artist='{}', album='{}'", song.getId(), name, artistName, albumName);

        processFileIntoChunks(file, song);
    }

    @Transactional
    public NegotiationResponseDto initiateNegotiation(NegotiationRequestDto request, Long userId) {
        log.info("[SONG] Negotiation initiated: name='{}', userId={}, totalChunks={}", request.getName(), userId, request.getHashes().size());
        Optional<Song> existingSongOpt = songRepository.findByFileHash(request.getFileHash());
        Song song;

        if (existingSongOpt.isPresent()) {
            song = existingSongOpt.get();
        } else {
            Artist artist = artistRepository.findByName(request.getArtistName())
                    .orElseGet(() -> artistRepository.save(Artist.builder().name(request.getArtistName()).build()));

            Album album = albumRepository.findByName(request.getAlbumName())
                    .orElseGet(() -> albumRepository.save(Album.builder().name(request.getAlbumName()).build()));

            song = songRepository.save(Song.builder()
                    .name(request.getName())
                    .artist(artist)
                    .album(album)
                    .fileHash(request.getFileHash())
                    .songType(SongType.USER_UPLOAD)
                    .ownerId(userId)
                    .durationInSeconds(request.getDurationInSeconds())
                    .trackNumber(request.getTrackNumber())
                    .discNumber(request.getDiscNumber())
                    .releaseYear(request.getReleaseYear())
                    .build());
        }

        List<Integer> missingIndices = new ArrayList<>();
        List<SongChunk> newLinks = new ArrayList<>();
        List<String> requestHashes = request.getHashes();

        for (int i = 0; i < requestHashes.size(); i++) {
            String hash = requestHashes.get(i);

            if (songChunkRepository.existsBySongAndOrderIndex(song, i)) {
                continue;
            }

            Optional<Chunk> existingChunk = chunkRepository.findByContentHash(hash);

            if (existingChunk.isPresent()) {
                newLinks.add(SongChunk.builder()
                        .song(song)
                        .chunk(existingChunk.get())
                        .orderIndex(i)
                        .build());
            } else {
                missingIndices.add(i);
            }
        }

        if (!newLinks.isEmpty()) {
            songChunkRepository.saveAll(newLinks);
        }

        log.info("[SONG] Negotiation complete: songId={}, missingChunks={}, deduplicatedChunks={}", song.getId(), missingIndices.size(), newLinks.size());
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

        Chunk chunk = chunkRepository.findByContentHash(calculatedHash).orElse(null);

        if (chunk == null) {
            String path = STORAGE_ROOT + "/" + calculatedHash;
            Files.createDirectories(Paths.get(STORAGE_ROOT));
            try (FileOutputStream fos = new FileOutputStream(path)) {
                fos.write(bytes);
            } catch (Exception e) {
                log.error("[SONG] Error writing chunk to disk: path={}, error={}", path, e.getMessage());
                throw new RuntimeException("Failed to save chunk to disk");
            }

            try {
                chunk = chunkRepository.save(Chunk.builder()
                        .contentHash(calculatedHash)
                        .size(bytes.length)
                        .storagePath(path)
                        .build());
            } catch (org.springframework.dao.DataIntegrityViolationException e) {
                chunk = chunkRepository.findByContentHash(calculatedHash)
                        .orElseThrow(() -> new RuntimeException("Concurrency recovery failed"));
            }
        }

        log.info("[SONG] Chunk received and verified: songId={}, chunkIndex={}, size={} bytes", songId, chunkIndex, bytes.length);

        boolean linkExists = songChunkRepository.existsBySongAndOrderIndex(song, chunkIndex);

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
        log.info("[SONG] Processed {} chunk(s) for songId={}", orderIndex, song.getId());
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

