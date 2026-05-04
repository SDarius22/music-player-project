package com.example.musicplayerbackend.service;

import com.example.musicplayerbackend.data.*;
import com.example.musicplayerbackend.domain.*;
import com.example.musicplayerbackend.helpers.CoverDecoder;
import com.example.musicplayerbackend.helpers.EntityHashHelper;
import com.example.musicplayerbackend.mapper.NegotiationMapper;
import com.example.musicplayerbackend.mapper.SongMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.FileOutputStream;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.security.MessageDigest;
import java.time.Instant;
import java.util.*;

@Slf4j
@Service
@RequiredArgsConstructor
public class SongService {

    private final SongRepository songRepository;
    private final ArtistRepository artistRepository;
    private final AlbumRepository albumRepository;
    private final ChunkRepository chunkRepository;
    private final SongChunkRepository songChunkRepository;
    private final UserLibraryRepository userLibraryRepository;
    private final SongMapper songMapper;
    private final SongEnrichmentService songEnrichmentService;
    private final NegotiationMapper negotiationMapper;

    private final String STORAGE_ROOT = System.getProperty("user.home") + "/music-server/chunks";


    @Transactional(readOnly = true)
    public Page<SongDto> getSongsVisibleToUser(String q, User user, Pageable pageable) {
        Page<Song> songs = songRepository.findVisibleToUser(q == null ? "" : q, user.getId(), pageable);
        List<SongDto> enriched = songEnrichmentService.enrich(songs.getContent(), user.getId());
        return new PageImpl<>(enriched, pageable, songs.getTotalElements());
    }

    @Transactional(readOnly = true)
    public SongDto getSongByFileHash(String fileHash, Long userId) {
        Song song = songRepository.findByFileHash(fileHash)
                .orElseThrow(() -> new RuntimeException("Song not found with fileHash: " + fileHash));
        return songEnrichmentService.enrich(song, userId);
    }

    @Transactional
    public SongDto updateUserSongLibrary(String fileHash, Long userId, UpdateUserSongDto patch) {
        Song song = songRepository.findByFileHash(fileHash)
                .orElseThrow(() -> new org.springframework.web.server.ResponseStatusException(
                        org.springframework.http.HttpStatus.NOT_FOUND, "Song not found"));

        Instant now = java.time.Instant.now();
        UserLibraryID id = new UserLibraryID(userId, song.getId());
        UserLibrary entry = userLibraryRepository.findById(id).orElseGet(() ->
                UserLibrary.builder()
                        .id(id)
                        .song(song)
                        .user(User.builder().id(userId).build())
                        .addedAt(now)
                        .build());

        if (patch != null) {
            if (patch.getLikedByUser() != null) {
                entry.setLiked(patch.getLikedByUser());
            }
            if (patch.getLastPlayed() != null) {
                entry.setLastPlayed(patch.getLastPlayed().toInstant());
            }
            if (patch.getPlayCount() != null) {
                entry.setPlayCount(Math.max(0L, patch.getPlayCount()));
            }
        }
        entry.setIsDeleted(false);
        entry.setLastUpdated(now);
        if (entry.getAddedAt() == null) {
            entry.setAddedAt(now);
        }

        UserLibrary saved = userLibraryRepository.save(entry);
        return songMapper.toDto(song, saved);
    }

    @Transactional(readOnly = true)
    public byte[] getSongCover(String fileHash) {
        Song song = songRepository.findByFileHash(fileHash)
                .orElseThrow(() -> new RuntimeException("Song not found with fileHash: " + fileHash));

        if (song.getAlbum() != null && song.getAlbum().getCoverImage() != null) {
            return CoverDecoder.decodeCoverImage(song.getAlbum().getCoverImage());
        } else {
            log.info("[SONG] No cover image found for fileHash={}", fileHash);
            return new byte[0];
        }
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
            existingSong.setSongType(ContentType.STREAMABLE);
            songRepository.save(existingSong);
            return;
        }

        var artistHash = EntityHashHelper.artistHash(artistName);
        var albumHash = EntityHashHelper.albumHash(albumName);

        Artist artist = artistRepository.findByHash(artistHash)
                .orElseGet(() -> artistRepository.save(
                        Artist.builder()
                                .hash(artistHash)
                                .name(artistName)
                                .artistType(ContentType.STREAMABLE)
                                .build()));

        Album album = albumRepository.findByHash(albumHash)
                .orElseGet(() -> albumRepository.save(
                        Album.builder()
                                .hash(albumHash)
                                .name(albumName)
                                .coverImage(photo)
                                .albumType(ContentType.STREAMABLE)
                                .build()));

        boolean artistAlreadyLinked = album.getArtists().stream()
                .anyMatch(existing -> existing.getId().equals(artist.getId()));
        if (!artistAlreadyLinked) {
            album.getArtists().add(artist);
            album = albumRepository.save(album);
        }

        Song song = Song.builder()
                .name(name)
                .artist(artist)
                .album(album)
                .songType(ContentType.STREAMABLE)
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
    public NegotiationResponseDto initiateNegotiation(NegotiationRequestDto request, Long userId) throws Exception {
        log.info("[SONG] Negotiation initiated: name='{}', userId={}, totalChunks={}", request.getName(), userId, request.getHashes().size());
        Optional<Song> existingSongOpt = songRepository.findByFileHash(request.getFileHash());
        Song song;

        if (existingSongOpt.isPresent()) {
            song = existingSongOpt.get();
        } else {

            var artistHash = EntityHashHelper.artistHash(request.getArtistName());
            var albumHash = EntityHashHelper.albumHash(request.getAlbumName());


            Artist artist = artistRepository.findByHash(artistHash)
                    .orElseGet(() -> artistRepository.save(
                            Artist.builder()
                                    .hash(artistHash)
                                    .name(request.getArtistName())
                                    .artistType(ContentType.USER_UPLOAD)
                                    .ownerId(userId).build()));

            Album album = albumRepository.findByHash(albumHash)
                    .orElseGet(() -> albumRepository.save(
                            Album.builder()
                                    .hash(albumHash)
                                    .name(request.getAlbumName())
                                    .albumType(ContentType.USER_UPLOAD)
                                    .ownerId(userId).build()));

            boolean artistAlreadyLinked = album.getArtists().stream()
                    .anyMatch(existing -> existing.getId().equals(artist.getId()));
            if (!artistAlreadyLinked) {
                album.getArtists().add(artist);
                album = albumRepository.save(album);
            }

            song = songRepository.save(Song.builder()
                    .name(request.getName())
                    .artist(artist)
                    .album(album)
                    .fileHash(request.getFileHash())
                    .songType(ContentType.USER_UPLOAD)
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

        log.info("[SONG] Negotiation complete: fileHash={}, missingChunks={}, deduplicatedChunks={}", song.getFileHash(), missingIndices.size(), newLinks.size());
        return negotiationMapper.toNegotiationResponseDto(song.getFileHash(), missingIndices);
    }


    @Transactional
    public void saveMissingChunk(User user, String fileHash, Integer chunkIndex, String contentHash, MultipartFile chunkFile) throws Exception {
        Song song = songRepository.findByFileHash(fileHash)
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

        log.info("[SONG] Chunk received and verified: fileHash={}, chunkIndex={}, size={} bytes", fileHash, chunkIndex, bytes.length);

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
        log.info("[SONG] Processed {} chunk(s) for fileHash={}", orderIndex, song.getId());
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

