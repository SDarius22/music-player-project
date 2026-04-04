package com.example.musicplayerbackend.service;

import com.example.musicplayerbackend.data.SongRepository;
import com.example.musicplayerbackend.data.UserLibraryRepository;
import com.example.musicplayerbackend.domain.Song;
import com.example.musicplayerbackend.domain.SongDto;
import com.example.musicplayerbackend.domain.UserLibrary;
import com.example.musicplayerbackend.mapper.SongMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

@Slf4j
@Service
@RequiredArgsConstructor
public class RecommendationService {

    private static final int LIMIT = 10;
    private static final long FORGOTTEN_DAYS = 30;
    private static final long RECENT_HOURS = 48;

    private final UserLibraryRepository userLibraryRepository;
    private final SongRepository songRepository;
    private final SongMapper songMapper;

    @Transactional(readOnly = true)
    public List<SongDto> getRecommendations(Long userId) {
        List<SongDto> result = new ArrayList<>(LIMIT);
        Set<String> seen = new HashSet<>();

        Instant recentCutoff = Instant.now().minus(RECENT_HOURS, ChronoUnit.HOURS);

        addFromLibrary(result, seen,
                userLibraryRepository.findLikedByUserId(userId, PageRequest.of(0, LIMIT / 2)));

        List<UserLibrary> mostPlayed =
                userLibraryRepository.findMostPlayedByUserId(userId, PageRequest.of(0, LIMIT * 2));

        for (UserLibrary ul : mostPlayed) {
            if (result.size() >= LIMIT) break;
            if (ul.getLastPlayed() != null && ul.getLastPlayed().isAfter(recentCutoff)) continue;
            Song song = ul.getSong();
            if (song != null && song.getFileHash() != null && seen.add(song.getFileHash())) {
                result.add(songMapper.toDto(song));
            }
        }

        padWithRandom(result, seen);

        log.debug("[RECOMMEND] userId={} → {} songs", userId, result.size());
        return result;
    }

    @Transactional(readOnly = true)
    public List<SongDto> getForgottenFavourites(Long userId) {
        Instant cutoff = Instant.now().minus(FORGOTTEN_DAYS, ChronoUnit.DAYS);
        List<UserLibrary> entries =
                userLibraryRepository.findForgottenByUserId(userId, cutoff, PageRequest.of(0, LIMIT));

        List<SongDto> result = new ArrayList<>(toSongDtos(entries));
        Set<String> seen = new HashSet<>();
        result.forEach(s -> seen.add(s.getFileHash()));

        padWithRandom(result, seen);

        log.debug("[FORGOTTEN] userId={} → {} songs", userId, result.size());
        return result;
    }

    @Transactional(readOnly = true)
    public List<SongDto> getQuickDial(Long userId) {
        List<SongDto> result = new ArrayList<>(LIMIT);
        Set<String> seen = new HashSet<>();

        addFromLibrary(result, seen,
                userLibraryRepository.findRecentlyPlayedByUserId(userId, PageRequest.of(0, LIMIT)));

        if (result.size() < LIMIT) {
            addFromLibrary(result, seen,
                    userLibraryRepository.findRecentlyAddedByUserId(
                            userId, PageRequest.of(0, LIMIT - result.size())));
        }

        padWithRandom(result, seen);

        log.debug("[QUICK_DIAL] userId={} → {} songs", userId, result.size());
        return result;
    }

    private void padWithRandom(List<SongDto> result, Set<String> seen) {
        if (result.size() >= LIMIT) return;
        List<Song> random = songRepository.findRandomStreamable(
                PageRequest.of(0, (LIMIT - result.size()) * 3));
        for (Song song : random) {
            if (result.size() >= LIMIT) break;
            if (song.getFileHash() != null && seen.add(song.getFileHash())) {
                result.add(songMapper.toDto(song));
            }
        }
    }

    private void addFromLibrary(List<SongDto> result, Set<String> seen, List<UserLibrary> entries) {
        for (UserLibrary ul : entries) {
            if (result.size() >= LIMIT) break;
            Song song = ul.getSong();
            if (song != null && song.getFileHash() != null && seen.add(song.getFileHash())) {
                result.add(songMapper.toDto(song));
            }
        }
    }

    private List<SongDto> toSongDtos(List<UserLibrary> entries) {
        List<SongDto> result = new ArrayList<>(entries.size());
        for (UserLibrary ul : entries) {
            Song song = ul.getSong();
            if (song != null) result.add(songMapper.toDto(song));
        }
        return result;
    }
}
