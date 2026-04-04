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
@Import({SongMapperImpl.class, ArtistMapperImpl.class, AlbumMapperImpl.class})
class SongMapperTest {

    @Autowired SongMapper songMapper;

    @Test
    void shouldMapAllSongFieldsToDto() {
        Artist artist = Artist.builder().id(1L).name("Queen").build();
        Album album = Album.builder().id(2L).name("Innuendo").coverImage("base64").build();
        Song song = Song.builder()
                .id(10L)
                .name("Bohemian Rhapsody")
                .fileHash("bohemian-hash")
                .artist(artist)
                .album(album)
                .durationInSeconds(354)
                .trackNumber(1)
                .discNumber(1)
                .build();

        SongDto dto = songMapper.toDto(song);

        assertEquals("bohemian-hash", dto.getFileHash());
        assertEquals("Bohemian Rhapsody", dto.getName());
        assertEquals(1L, dto.getArtist().getId());
        assertEquals(2L, dto.getAlbum().getId());
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

        assertNull(dto.getArtist());
        assertNull(dto.getAlbum());
    }

    @Test
    void shouldMapSongIdAndNameToEntity() {
        SongDto dto = new SongDto();
        dto.setFileHash("stairway-hash");
        dto.setName("Stairway to Heaven");
        dto.setDurationInSeconds(482);

        Song entity = songMapper.toEntity(dto);

        assertEquals("stairway-hash", entity.getFileHash());
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
