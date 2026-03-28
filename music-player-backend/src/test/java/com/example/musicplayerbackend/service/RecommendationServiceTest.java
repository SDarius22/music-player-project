package com.example.musicplayerbackend.service;

import com.example.musicplayerbackend.data.SongRepository;
import com.example.musicplayerbackend.data.UserLibraryRepository;
import com.example.musicplayerbackend.domain.*;
import com.example.musicplayerbackend.mapper.SongMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Collections;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class RecommendationServiceTest {

    private static final int LIMIT = 10;

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
    }

    private Song song(long id) {
        return Song.builder().id(id).name("Song " + id).songType(ContentType.STREAMABLE)
                .fileHash("hash-" + id).build();
    }

    private SongDto songDto(long id) {
        SongDto dto = new SongDto();
        dto.setId(id);
        return dto;
    }

    private UserLibrary libraryEntry(Song song, boolean liked, long playCount, Instant lastPlayed) {
        User user = User.builder().id(1L).email("u@t.com").role(Role.USER)
                .provider(AuthProvider.LOCAL).build();
        return UserLibrary.builder()
                .id(new UserLibraryID(1L, song.getId()))
                .song(song).user(user)
                .liked(liked).playCount(playCount).lastPlayed(lastPlayed)
                .isDeleted(false).lastUpdated(Instant.now())
                .build();
    }

    @Test
    void shouldReturnRecommendationsUpToLimit() {
        List<UserLibrary> liked = List.of();
        List<UserLibrary> mostPlayed = List.of();

        when(userLibraryRepository.findLikedByUserId(eq(1L), any())).thenReturn(liked);
        when(userLibraryRepository.findMostPlayedByUserId(eq(1L), any())).thenReturn(mostPlayed);
        when(songMapper.toDto(any(Song.class))).thenAnswer(inv ->
                songDto(((Song) inv.getArgument(0)).getId()));

        // Pad with LIMIT random songs
        List<Song> random = List.of(song(1), song(2), song(3), song(4), song(5),
                song(6), song(7), song(8), song(9), song(10));
        when(songRepository.findRandomStreamable(any())).thenReturn(random);

        List<SongDto> result = service.getRecommendations(1L);

        assertEquals(LIMIT, result.size());
    }

    @Test
    void shouldExcludeRecentlyPlayedFromRecommendations() {
        Song recentSong = song(1);
        UserLibrary recentEntry = libraryEntry(recentSong, false, 10L,
                Instant.now().minus(1, ChronoUnit.HOURS)); // played 1 hour ago → excluded

        when(songMapper.toDto(any(Song.class))).thenAnswer(inv ->
                songDto(((Song) inv.getArgument(0)).getId()));
        when(userLibraryRepository.findLikedByUserId(eq(1L), any())).thenReturn(List.of());
        when(userLibraryRepository.findMostPlayedByUserId(eq(1L), any()))
                .thenReturn(List.of(recentEntry));
        // Should fallback to random to fill LIMIT
        when(songRepository.findRandomStreamable(any())).thenReturn(
                List.of(song(10), song(11), song(12), song(13), song(14),
                        song(15), song(16), song(17), song(18), song(19)));

        List<SongDto> result = service.getRecommendations(1L);

        assertEquals(LIMIT, result.size());
        assertTrue(result.stream().noneMatch(s -> s.getId() == 1L));
    }

    @Test
    void shouldIncludeMostPlayedSongsWithNullLastPlayed() {
        // lastPlayed = null → condition is false → NOT excluded from most-played
        Song s = song(1);
        UserLibrary entry = libraryEntry(s, false, 5L, null); // null lastPlayed

        when(songMapper.toDto(any(Song.class))).thenAnswer(inv ->
                songDto(((Song) inv.getArgument(0)).getId()));
        when(userLibraryRepository.findLikedByUserId(eq(1L), any())).thenReturn(List.of());
        when(userLibraryRepository.findMostPlayedByUserId(eq(1L), any()))
                .thenReturn(List.of(entry));
        when(songRepository.findRandomStreamable(any())).thenReturn(
                List.of(song(2), song(3), song(4), song(5), song(6),
                        song(7), song(8), song(9), song(10), song(11)));

        List<SongDto> result = service.getRecommendations(1L);

        assertTrue(result.stream().anyMatch(d -> d.getId() == 1L),
                "Song with null lastPlayed should NOT be excluded");
    }

    @Test
    void shouldDeduplicateSongsInRecommendations() {
        Song s = song(1);
        UserLibrary likedEntry = libraryEntry(s, true, 5L, null);
        UserLibrary mostPlayedEntry = libraryEntry(s, false, 5L,
                Instant.now().minus(72, ChronoUnit.HOURS)); // old enough

        when(songMapper.toDto(any(Song.class))).thenAnswer(inv ->
                songDto(((Song) inv.getArgument(0)).getId()));
        when(userLibraryRepository.findLikedByUserId(eq(1L), any()))
                .thenReturn(List.of(likedEntry));
        when(userLibraryRepository.findMostPlayedByUserId(eq(1L), any()))
                .thenReturn(List.of(mostPlayedEntry));
        when(songRepository.findRandomStreamable(any())).thenReturn(
                List.of(song(2), song(3), song(4), song(5),
                        song(6), song(7), song(8), song(9), song(10), song(11)));

        List<SongDto> result = service.getRecommendations(1L);

        long count = result.stream().filter(d -> d.getId() == 1L).count();
        assertEquals(1, count, "Song 1 should appear exactly once");
    }

    @Test
    void shouldReturnForgottenFavouritesWithPadding() {
        Song s = song(1);
        UserLibrary entry = libraryEntry(s, true, 3L,
                Instant.now().minus(40, ChronoUnit.DAYS));
        when(songMapper.toDto(any(Song.class))).thenAnswer(inv ->
                songDto(((Song) inv.getArgument(0)).getId()));
        when(userLibraryRepository.findForgottenByUserId(eq(1L), any(), any()))
                .thenReturn(List.of(entry));
        when(songRepository.findRandomStreamable(any())).thenReturn(
                List.of(song(2), song(3), song(4), song(5), song(6),
                        song(7), song(8), song(9), song(10), song(11)));

        List<SongDto> result = service.getForgottenFavourites(1L);

        assertEquals(LIMIT, result.size());
        assertTrue(result.stream().anyMatch(d -> d.getId() == 1L));
    }

    @Test
    void shouldSkipNullSongInForgottenFavouritesEntries() {
        User user = User.builder().id(1L).email("u@t.com").role(Role.USER)
                .provider(AuthProvider.LOCAL).build();
        UserLibrary badEntry = UserLibrary.builder()
                .id(new UserLibraryID(1L, 999L))
                .song(null) // null song → toSongDtos skips it
                .user(user)
                .liked(false).playCount(0L).isDeleted(false)
                .lastUpdated(Instant.now()).build();
        when(songMapper.toDto(any(Song.class))).thenAnswer(inv ->
                songDto(((Song) inv.getArgument(0)).getId()));
        when(userLibraryRepository.findForgottenByUserId(eq(1L), any(), any()))
                .thenReturn(List.of(badEntry));
        when(songRepository.findRandomStreamable(any())).thenReturn(
                List.of(song(1), song(2), song(3), song(4), song(5),
                        song(6), song(7), song(8), song(9), song(10)));

        List<SongDto> result = service.getForgottenFavourites(1L);

        assertEquals(LIMIT, result.size());
        assertTrue(result.stream().noneMatch(s -> s.getId() == 999L));
    }

    @Test
    void shouldNotPadForgottenFavouritesWhenAlreadyAtLimit() {
        when(songMapper.toDto(any(Song.class))).thenAnswer(inv ->
                songDto(((Song) inv.getArgument(0)).getId()));
        // LIMIT entries → padWithRandom returns early → findRandomStreamable never called
        List<UserLibrary> fullList = List.of(
                libraryEntry(song(1), true, 5L, Instant.now().minus(40, ChronoUnit.DAYS)),
                libraryEntry(song(2), true, 4L, Instant.now().minus(40, ChronoUnit.DAYS)),
                libraryEntry(song(3), true, 3L, Instant.now().minus(40, ChronoUnit.DAYS)),
                libraryEntry(song(4), true, 3L, Instant.now().minus(40, ChronoUnit.DAYS)),
                libraryEntry(song(5), true, 2L, Instant.now().minus(40, ChronoUnit.DAYS)),
                libraryEntry(song(6), true, 2L, Instant.now().minus(40, ChronoUnit.DAYS)),
                libraryEntry(song(7), true, 1L, Instant.now().minus(40, ChronoUnit.DAYS)),
                libraryEntry(song(8), true, 1L, Instant.now().minus(40, ChronoUnit.DAYS)),
                libraryEntry(song(9), true, 1L, Instant.now().minus(40, ChronoUnit.DAYS)),
                libraryEntry(song(10), true, 1L, Instant.now().minus(40, ChronoUnit.DAYS)));
        when(userLibraryRepository.findForgottenByUserId(eq(1L), any(), any()))
                .thenReturn(fullList);

        List<SongDto> result = service.getForgottenFavourites(1L);

        assertEquals(LIMIT, result.size());
        verify(songRepository, never()).findRandomStreamable(any());
    }

    @Test
    void shouldPadForgottenFavouritesWhenLibraryIsEmpty() {
        when(songMapper.toDto(any(Song.class))).thenAnswer(inv ->
                songDto(((Song) inv.getArgument(0)).getId()));
        when(userLibraryRepository.findForgottenByUserId(eq(1L), any(), any()))
                .thenReturn(Collections.emptyList());
        when(songRepository.findRandomStreamable(any())).thenReturn(
                List.of(song(1), song(2), song(3), song(4), song(5),
                        song(6), song(7), song(8), song(9), song(10)));

        List<SongDto> result = service.getForgottenFavourites(1L);

        assertEquals(LIMIT, result.size());
    }

    @Test
    void shouldPreferRecentlyPlayedInQuickDial() {
        Song s = song(1);
        UserLibrary recent = libraryEntry(s, false, 1L, Instant.now().minus(1, ChronoUnit.HOURS));
        when(songMapper.toDto(any(Song.class))).thenAnswer(inv ->
                songDto(((Song) inv.getArgument(0)).getId()));
        when(userLibraryRepository.findRecentlyPlayedByUserId(eq(1L), any()))
                .thenReturn(List.of(recent));
        when(userLibraryRepository.findRecentlyAddedByUserId(eq(1L), any()))
                .thenReturn(Collections.emptyList());
        when(songRepository.findRandomStreamable(any())).thenReturn(
                List.of(song(2), song(3), song(4), song(5), song(6),
                        song(7), song(8), song(9), song(10), song(11)));

        List<SongDto> result = service.getQuickDial(1L);

        assertEquals(LIMIT, result.size());
        assertTrue(result.getFirst().getId() == 1L);
    }

    @Test
    void shouldSkipRecentlyAddedInQuickDialWhenAlreadyAtLimit() {
        // 10 recently played → result already at LIMIT → findRecentlyAddedByUserId NOT called
        when(songMapper.toDto(any(Song.class))).thenAnswer(inv ->
                songDto(((Song) inv.getArgument(0)).getId()));
        List<UserLibrary> tenPlayed = List.of(
                libraryEntry(song(1), false, 1L, Instant.now().minus(1, ChronoUnit.HOURS)),
                libraryEntry(song(2), false, 1L, Instant.now().minus(2, ChronoUnit.HOURS)),
                libraryEntry(song(3), false, 1L, Instant.now().minus(3, ChronoUnit.HOURS)),
                libraryEntry(song(4), false, 1L, Instant.now().minus(4, ChronoUnit.HOURS)),
                libraryEntry(song(5), false, 1L, Instant.now().minus(5, ChronoUnit.HOURS)),
                libraryEntry(song(6), false, 1L, Instant.now().minus(6, ChronoUnit.HOURS)),
                libraryEntry(song(7), false, 1L, Instant.now().minus(7, ChronoUnit.HOURS)),
                libraryEntry(song(8), false, 1L, Instant.now().minus(8, ChronoUnit.HOURS)),
                libraryEntry(song(9), false, 1L, Instant.now().minus(9, ChronoUnit.HOURS)),
                libraryEntry(song(10), false, 1L, Instant.now().minus(10, ChronoUnit.HOURS)));
        when(userLibraryRepository.findRecentlyPlayedByUserId(eq(1L), any())).thenReturn(tenPlayed);

        List<SongDto> result = service.getQuickDial(1L);

        assertEquals(LIMIT, result.size());
        verify(userLibraryRepository, never()).findRecentlyAddedByUserId(any(), any());
    }

    @Test
    void shouldPadQuickDialWithRandomWhenBothListsAreEmpty() {
        when(songMapper.toDto(any(Song.class))).thenAnswer(inv ->
                songDto(((Song) inv.getArgument(0)).getId()));
        when(userLibraryRepository.findRecentlyPlayedByUserId(eq(1L), any()))
                .thenReturn(Collections.emptyList());
        when(userLibraryRepository.findRecentlyAddedByUserId(eq(1L), any()))
                .thenReturn(Collections.emptyList());
        when(songRepository.findRandomStreamable(any())).thenReturn(
                List.of(song(1), song(2), song(3), song(4), song(5),
                        song(6), song(7), song(8), song(9), song(10)));

        List<SongDto> result = service.getQuickDial(1L);

        assertEquals(LIMIT, result.size());
    }

    @Test
    void shouldSkipNullSongsInQuickDial() {
        when(songMapper.toDto(any(Song.class))).thenAnswer(inv ->
                songDto(((Song) inv.getArgument(0)).getId()));
        UserLibrary badEntry = UserLibrary.builder()
                .id(new UserLibraryID(1L, 999L))
                .song(null).user(null)
                .liked(false).playCount(0L).isDeleted(false)
                .lastUpdated(Instant.now()).build();
        when(userLibraryRepository.findRecentlyPlayedByUserId(eq(1L), any()))
                .thenReturn(List.of(badEntry));
        when(userLibraryRepository.findRecentlyAddedByUserId(eq(1L), any()))
                .thenReturn(Collections.emptyList());
        when(songRepository.findRandomStreamable(any())).thenReturn(
                List.of(song(1), song(2), song(3), song(4), song(5),
                        song(6), song(7), song(8), song(9), song(10)));

        List<SongDto> result = service.getQuickDial(1L);

        assertEquals(LIMIT, result.size());
        assertTrue(result.stream().noneMatch(s -> s.getId() == 999L));
    }
}
