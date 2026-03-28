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
@Import({SongMapperImpl.class})
class SongMapperTest {

    @Autowired SongMapper songMapper;

    @Test
    void shouldMapAllSongFieldsToDto() {
        Artist artist = Artist.builder().id(1L).name("Queen").build();
        Album album = Album.builder().id(2L).name("Innuendo").coverImage("base64").build();
        Song song = Song.builder()
                .id(10L)
                .name("Bohemian Rhapsody")
                .artist(artist)
                .album(album)
                .durationInSeconds(354)
                .trackNumber(1)
                .discNumber(1)
                .build();

        SongDto dto = songMapper.toDto(song);

        assertEquals(10L, dto.getId());
        assertEquals("Bohemian Rhapsody", dto.getName());
        assertEquals(1L, dto.getArtistId());
        assertEquals(2L, dto.getAlbumId());
        assertEquals(354, dto.getDurationInSeconds());
        assertEquals(1, dto.getTrackNumber());
        assertEquals(1, dto.getDiscNumber());
    }

    @Test
    void shouldReturnNullWhenSongToDtoInputIsNull() {
        assertNull(songMapper.toDto(null));
    }

    @Test
    void shouldMapNullArtistAndAlbumToNullInDto() {
        Song song = Song.builder().id(5L).name("No Artist Song")
                .songType(ContentType.STREAMABLE).fileHash("hash1").build();

        SongDto dto = songMapper.toDto(song);

        assertNull(dto.getArtistId());
        assertNull(dto.getAlbumId());
    }

    @Test
    void shouldMapSongIdAndNameToEntity() {
        SongDto dto = new SongDto();
        dto.setId(7L);
        dto.setName("Stairway to Heaven");
        dto.setDurationInSeconds(482);

        Song entity = songMapper.toEntity(dto);

        assertEquals(7L, entity.getId());
        assertEquals("Stairway to Heaven", entity.getName());
        assertEquals(482, entity.getDurationInSeconds());
    }

    @Test
    void shouldReturnNullWhenSongToEntityInputIsNull() {
        assertNull(songMapper.toEntity(null));
    }

    @Test
    void shouldConvertInstantToUtcOffsetDateTime() {
        Instant instant = Instant.parse("2024-01-15T10:00:00Z");

        OffsetDateTime result = songMapper.map(instant);

        assertNotNull(result);
        assertEquals(ZoneOffset.UTC, result.getOffset());
        assertEquals(instant, result.toInstant());
    }

    @Test
    void shouldReturnNullWhenInstantToOffsetDateTimeInputIsNull() {
        assertNull(songMapper.map((Instant) null));
    }

    @Test
    void shouldConvertOffsetDateTimeToInstant() {
        OffsetDateTime odt = OffsetDateTime.parse("2024-06-01T12:00:00+02:00");

        Instant result = songMapper.map(odt);

        assertNotNull(result);
        assertEquals(odt.toInstant(), result);
    }

    @Test
    void shouldReturnNullWhenOffsetDateTimeToInstantInputIsNull() {
        assertNull(songMapper.map((OffsetDateTime) null));
    }
}
