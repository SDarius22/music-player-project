package com.example.musicplayerbackend.service;

import com.example.musicplayerbackend.data.UserLibraryRepository;
import com.example.musicplayerbackend.domain.SongDto;
import com.example.musicplayerbackend.mapper.SongMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.temporal.ChronoUnit;

@Slf4j
@Service
@RequiredArgsConstructor
public class RecommendationService {

    private static final long FORGOTTEN_DAYS = 30;
    private static final long RECENT_HOURS = 48;

    private final UserLibraryRepository userLibraryRepository;
    private final SongMapper songMapper;

    @Transactional(readOnly = true)
    public Page<SongDto> getRecommendations(Long userId, Pageable pageable) {
        Instant cutoff = Instant.now().minus(RECENT_HOURS, ChronoUnit.HOURS);
        return userLibraryRepository.findRecommendationsByUserId(userId, cutoff, pageable)
                .map(entry -> songMapper.toDto(entry.getSong(), entry));
    }

    @Transactional(readOnly = true)
    public Page<SongDto> getForgottenFavourites(Long userId, Pageable pageable) {
        Instant cutoff = Instant.now().minus(FORGOTTEN_DAYS, ChronoUnit.DAYS);
        return userLibraryRepository.findForgottenByUserId(userId, cutoff, pageable)
                .map(entry -> songMapper.toDto(entry.getSong(), entry));
    }

    @Transactional(readOnly = true)
    public Page<SongDto> getQuickDial(Long userId, Pageable pageable) {
        return userLibraryRepository.findQuickDialByUserId(userId, pageable)
                .map(entry -> songMapper.toDto(entry.getSong(), entry));
    }

    @Transactional(readOnly = true)
    public Page<SongDto> getFavourites(Long userId, Pageable pageable) {
        return userLibraryRepository.findLikedByUserId(userId, pageable)
                .map(entry -> songMapper.toDto(entry.getSong(), entry));
    }

    @Transactional(readOnly = true)
    public Page<SongDto> getMostPlayed(Long userId, Pageable pageable) {
        return userLibraryRepository.findMostPlayedByUserId(userId, pageable)
                .map(entry -> songMapper.toDto(entry.getSong(), entry));
    }

    @Transactional(readOnly = true)
    public Page<SongDto> getRecentlyPlayed(Long userId, Pageable pageable) {
        return userLibraryRepository.findRecentlyPlayedByUserId(userId, pageable)
                .map(entry -> songMapper.toDto(entry.getSong(), entry));
    }
}
