package com.example.musicplayerbackend.service;

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
    // Songs played within this window are considered "too fresh" for recommendations.
    private static final long RECENT_HOURS = 48;

    private final UserLibraryRepository userLibraryRepository;
    private final SongMapper songMapper;

    /**
     * Heuristic recommendations: blends liked songs (weighted by play count)
     * with the user's overall most-played tracks. Songs played in the last
     * 48 hours are excluded to keep the list fresh.
     */
    @Transactional(readOnly = true)
    public List<SongDto> getRecommendations(Long userId) {
        List<SongDto> result = new ArrayList<>(LIMIT);
        Set<Long> seen = new HashSet<>();

        Instant recentCutoff = Instant.now().minus(RECENT_HOURS, ChronoUnit.HOURS);

        // Half from liked songs (ordered by play count so most-loved come first).
        addFromLibrary(result, seen,
                userLibraryRepository.findLikedByUserId(userId, PageRequest.of(0, LIMIT / 2)));

        // Fill remaining from overall most-played, skipping recently played ones.
        List<UserLibrary> mostPlayed =
                userLibraryRepository.findMostPlayedByUserId(userId, PageRequest.of(0, LIMIT * 2));
        for (UserLibrary ul : mostPlayed) {
            if (result.size() >= LIMIT) break;
            if (ul.getLastPlayed() != null && ul.getLastPlayed().isAfter(recentCutoff)) continue;
            Song song = ul.getSong();
            if (song != null && seen.add(song.getId())) {
                result.add(songMapper.toDto(song));
            }
        }

        log.debug("[RECOMMEND] userId={} → {} songs", userId, result.size());
        return result;
    }

    /**
     * Forgotten favourites: songs the user played at least once but hasn't
     * touched in the last 30 days, surfaced by play count so their old
     * favourites appear first.
     */
    @Transactional(readOnly = true)
    public List<SongDto> getForgottenFavourites(Long userId) {
        Instant cutoff = Instant.now().minus(FORGOTTEN_DAYS, ChronoUnit.DAYS);
        List<UserLibrary> entries =
                userLibraryRepository.findForgottenByUserId(userId, cutoff, PageRequest.of(0, LIMIT));

        List<SongDto> result = toSongDtos(entries);
        log.debug("[FORGOTTEN] userId={} → {} songs", userId, result.size());
        return result;
    }

    /**
     * Quick dial: the user's most recently played tracks for instant access,
     * padded with most recently added songs when the played list is short.
     */
    @Transactional(readOnly = true)
    public List<SongDto> getQuickDial(Long userId) {
        List<SongDto> result = new ArrayList<>(LIMIT);
        Set<Long> seen = new HashSet<>();

        // Recently played first.
        addFromLibrary(result, seen,
                userLibraryRepository.findRecentlyPlayedByUserId(userId, PageRequest.of(0, LIMIT)));

        // Pad with recently added if we don't have enough.
        if (result.size() < LIMIT) {
            addFromLibrary(result, seen,
                    userLibraryRepository.findRecentlyAddedByUserId(
                            userId, PageRequest.of(0, LIMIT - result.size())));
        }

        log.debug("[QUICK_DIAL] userId={} → {} songs", userId, result.size());
        return result;
    }

    // ── helpers ────────────────────────────────────────────────────────────────

    private void addFromLibrary(List<SongDto> result, Set<Long> seen, List<UserLibrary> entries) {
        for (UserLibrary ul : entries) {
            if (result.size() >= LIMIT) break;
            Song song = ul.getSong();
            if (song != null && seen.add(song.getId())) {
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
