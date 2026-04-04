package com.example.musicplayerbackend.mapper;

import com.example.musicplayerbackend.domain.*;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.junit.jupiter.SpringExtension;

import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;

import static org.junit.jupiter.api.Assertions.*;

@ExtendWith(SpringExtension.class)
@Import(SyncMapperImpl.class)
class SyncMapperTest {

    @Autowired SyncMapper syncMapper;

    private UserLibrary buildLibrary(Song song, Boolean liked, Long playCount,
                                     Instant lastPlayed, Instant addedAt, Boolean isDeleted) {
        return UserLibrary.builder()
                .id(new UserLibraryID(1L, song != null ? song.getId() : null))
                .song(song)
                .liked(liked)
                .playCount(playCount)
                .lastPlayed(lastPlayed)
                .addedAt(addedAt)
                .lastUpdated(Instant.now())
                .isDeleted(isDeleted)
                .build();
    }

    @Test
    void shouldMapAllSyncFieldsToDto() {
        Song song = Song.builder().id(10L).name("Get Back").songType(ContentType.STREAMABLE)
                .fileHash("hash").build();
        Instant now = Instant.now();
        UserLibrary library = buildLibrary(song, true, 5L, now, now, false);

        SongSyncDto dto = syncMapper.toDto(library);

        assertEquals("hash", dto.getFileHash());
        assertEquals(true, dto.getLikedByUser());
        assertEquals(0, dto.getPlayCountDelta()); // constant
        assertFalse(dto.getIsDeleted());
        assertNotNull(dto.getLastPlayed());
        assertNotNull(dto.getAddedAt());
        assertNotNull(dto.getSongMetadata());
        assertEquals("Get Back", dto.getSongMetadata().getName());
    }

    @Test
    void shouldReturnNullWhenUserLibraryToDtoInputIsNull() {
        assertNull(syncMapper.toDto(null));
    }

    @Test
    void shouldMapNullSongToNullSongId() {
        UserLibrary library = buildLibrary(null, false, 0L, null, null, false);

        SongSyncDto dto = syncMapper.toDto(library);

        assertNull(dto.getFileHash());
        assertNull(dto.getSongMetadata());
    }

    @Test
    void shouldMapNullLastPlayedToNullOffsetDateTime() {
        Song song = Song.builder().id(1L).name("Song").songType(ContentType.STREAMABLE)
                .fileHash("h").build();
        UserLibrary library = buildLibrary(song, false, 0L, null, null, false);

        SongSyncDto dto = syncMapper.toDto(library);

        assertNull(dto.getLastPlayed());
        assertNull(dto.getAddedAt());
    }

    @Test
    void shouldAlwaysSetPlayCountDeltaToZero() {
        Song song = Song.builder().id(2L).name("Song2").songType(ContentType.STREAMABLE)
                .fileHash("h2").build();
        UserLibrary library = buildLibrary(song, false, 100L, null, null, false);

        SongSyncDto dto = syncMapper.toDto(library);

        assertEquals(0, dto.getPlayCountDelta());
    }

    @Test
    void shouldSetIsDeletdTrueInDto() {
        Song song = Song.builder().id(3L).name("Song3").songType(ContentType.STREAMABLE)
                .fileHash("h3").build();
        UserLibrary library = buildLibrary(song, false, 0L, null, null, true);

        SongSyncDto dto = syncMapper.toDto(library);

        assertTrue(dto.getIsDeleted());
    }

    @Test
    void shouldConvertSyncInstantToUtcOffsetDateTime() {
        Instant instant = Instant.parse("2025-03-01T08:00:00Z");

        OffsetDateTime result = syncMapper.map(instant);

        assertNotNull(result);
        assertEquals(ZoneOffset.UTC, result.getOffset());
    }

    @Test
    void shouldReturnNullWhenSyncInstantToOffsetDateTimeInputIsNull() {
        assertNull(syncMapper.map((Instant) null));
    }

    @Test
    void shouldConvertSyncOffsetDateTimeToInstant() {
        OffsetDateTime odt = OffsetDateTime.parse("2025-06-15T10:00:00Z");

        Instant result = syncMapper.map(odt);

        assertEquals(odt.toInstant(), result);
    }

    @Test
    void shouldReturnNullWhenSyncOffsetDateTimeToInstantInputIsNull() {
        assertNull(syncMapper.map((OffsetDateTime) null));
    }
}
