package com.example.musicplayerbackend.service;

import com.example.musicplayerbackend.data.SongRepository;
import com.example.musicplayerbackend.data.UserLibraryRepository;
import com.example.musicplayerbackend.domain.*;
import com.example.musicplayerbackend.mapper.SongMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class RecommendationServiceTest {

    @Mock
    UserLibraryRepository userLibraryRepository;
    @Mock
    SongRepository songRepository;
    @Mock
    SongMapper songMapper;

    RecommendationService service;

    @BeforeEach
    void setUp() {
        service = new RecommendationService(userLibraryRepository, songRepository, songMapper);
        lenient().when(songMapper.toDto(any(Song.class), any(UserLibrary.class))).thenAnswer(inv ->
                songDto(((Song) inv.getArgument(0)).getId()));
        lenient().when(songMapper.toDto(any(Song.class), org.mockito.ArgumentMatchers.isNull())).thenAnswer(inv ->
                songDto(((Song) inv.getArgument(0)).getId()));
        lenient().when(songRepository.findRandomStreamable(any())).thenReturn(List.of());
    }

    private Song song(long id) {
        return Song.builder().id(id).name("Song " + id).songType(ContentType.STREAMABLE)
                .fileHash("hash-" + id).build();
    }

    private SongDto songDto(long id) {
        SongDto dto = new SongDto();
        dto.setFileHash("hash-" + id);
        return dto;
    }

    private UserLibrary entry(Song song) {
        return UserLibrary.builder()
                .id(new UserLibraryID(1L, song.getId()))
                .song(song)
                .liked(false).playCount(0L).isDeleted(false)
                .lastUpdated(Instant.now())
                .build();
    }

    private Page<UserLibrary> page(List<UserLibrary> entries, Pageable pageable, long total) {
        return new PageImpl<>(entries, pageable, total);
    }

    @Test
    void shouldMapRecommendationsPageThroughSongMapper() {
        Pageable pageable = PageRequest.of(0, 50);
        when(userLibraryRepository.findRecommendationsByUserId(eq(1L), any(), eq(pageable)))
                .thenReturn(page(List.of(entry(song(1)), entry(song(2))), pageable, 2));

        Page<SongDto> result = service.getRecommendations(1L, pageable);

        assertEquals(2, result.getContent().size());
        assertEquals(List.of("hash-1", "hash-2"),
                result.getContent().stream().map(SongDto::getFileHash).toList());
    }

    @Test
    void shouldUseRecentCutoffWhenFetchingRecommendations() {
        Pageable pageable = PageRequest.of(0, 10);
        ArgumentCaptor<Instant> cutoffCaptor = ArgumentCaptor.forClass(Instant.class);
        when(userLibraryRepository.findRecommendationsByUserId(eq(1L), cutoffCaptor.capture(), eq(pageable)))
                .thenReturn(Page.empty(pageable));

        service.getRecommendations(1L, pageable);

        // Cutoff should be ~48 hours ago (allow generous slack for test execution time).
        Instant expected = Instant.now().minus(48, ChronoUnit.HOURS);
        long deltaSeconds = Math.abs(expected.getEpochSecond() - cutoffCaptor.getValue().getEpochSecond());
        assertTrue(deltaSeconds < 60, "Recent cutoff should be ~48h ago, was " + cutoffCaptor.getValue());
    }

    @Test
    void shouldUseForgottenCutoffWhenFetchingForgottenFavourites() {
        Pageable pageable = PageRequest.of(0, 50);
        ArgumentCaptor<Instant> cutoffCaptor = ArgumentCaptor.forClass(Instant.class);
        when(userLibraryRepository.findForgottenByUserId(eq(1L), cutoffCaptor.capture(), eq(pageable)))
                .thenReturn(Page.empty(pageable));

        service.getForgottenFavourites(1L, pageable);

        // Cutoff should be ~30 days ago.
        Instant expected = Instant.now().minus(30, ChronoUnit.DAYS);
        long deltaSeconds = Math.abs(expected.getEpochSecond() - cutoffCaptor.getValue().getEpochSecond());
        assertTrue(deltaSeconds < 60, "Forgotten cutoff should be ~30d ago, was " + cutoffCaptor.getValue());
    }

    @Test
    void shouldDelegateQuickDialToRepository() {
        Pageable pageable = PageRequest.of(1, 20);
        when(userLibraryRepository.findQuickDialByUserId(1L, pageable))
                .thenReturn(page(List.of(entry(song(7))), pageable, 1));

        Page<SongDto> result = service.getQuickDial(1L, pageable);

        assertEquals(1, result.getContent().size());
        assertEquals("hash-7", result.getContent().getFirst().getFileHash());
        verify(userLibraryRepository).findQuickDialByUserId(1L, pageable);
    }

    @Test
    void shouldDelegateFavouritesToLikedQuery() {
        Pageable pageable = PageRequest.of(0, 50);
        when(userLibraryRepository.findLikedByUserId(1L, pageable))
                .thenReturn(page(List.of(entry(song(3))), pageable, 1));

        Page<SongDto> result = service.getFavourites(1L, pageable);

        assertEquals(1, result.getContent().size());
        assertEquals("hash-3", result.getContent().getFirst().getFileHash());
    }

    @Test
    void shouldDelegateMostPlayedToRepository() {
        Pageable pageable = PageRequest.of(0, 50);
        when(userLibraryRepository.findMostPlayedByUserId(1L, pageable))
                .thenReturn(page(List.of(entry(song(4))), pageable, 1));

        Page<SongDto> result = service.getMostPlayed(1L, pageable);

        assertEquals(1, result.getContent().size());
        assertEquals("hash-4", result.getContent().getFirst().getFileHash());
    }

    @Test
    void shouldDelegateRecentlyPlayedToRepository() {
        Pageable pageable = PageRequest.of(0, 50);
        when(userLibraryRepository.findRecentlyPlayedByUserId(1L, pageable))
                .thenReturn(page(List.of(entry(song(5))), pageable, 1));

        Page<SongDto> result = service.getRecentlyPlayed(1L, pageable);

        assertEquals(1, result.getContent().size());
        assertEquals("hash-5", result.getContent().getFirst().getFileHash());
    }
}
