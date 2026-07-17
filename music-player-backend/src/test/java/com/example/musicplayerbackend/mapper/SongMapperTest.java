package com.example.musicplayerbackend.mapper;

import static org.junit.jupiter.api.Assertions.*;

import com.example.musicplayerbackend.domain.*;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.junit.jupiter.SpringExtension;

@ExtendWith(SpringExtension.class)
@Import({SongMapperImpl.class, ArtistMapperImpl.class, AlbumMapperImpl.class})
class SongMapperTest {

  @Autowired SongMapper songMapper;

  @Autowired ArtistMapper artistMapper;

  @Autowired AlbumMapper albumMapper;

  @Test
  void shouldMapAllSongFieldsToDto() {
    Artist artist = Artist.builder().id(1L).hash("queen-hash").name("Queen").build();
    Album album =
        Album.builder().id(2L).hash("innuendo-hash").name("Innuendo").coverImage("base64").build();
    Song song =
        Song.builder()
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
    assertEquals("queen-hash", dto.getArtist().getHash());
    assertEquals("innuendo-hash", dto.getAlbum().getHash());
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
    Song song =
        Song.builder()
            .id(5L)
            .name("No Artist Song")
            .songType(ContentType.STREAMABLE)
            .fileHash("hash1")
            .build();

    SongDto dto = songMapper.toDto(song);

    assertNull(dto.getArtist());
    assertNull(dto.getAlbum());
  }

  @Test
  void shouldEnrichSongDtoFromUserLibraryEntry() {
    Song song = Song.builder().name("Song").fileHash("hash").build();
    Instant lastPlayed = Instant.parse("2026-07-17T12:00:00Z");
    UserLibrary entry =
        UserLibrary.builder().lastPlayed(lastPlayed).playCount(7L).liked(true).build();

    SongDto dto = songMapper.toDto(song, entry);

    assertEquals(lastPlayed.atOffset(ZoneOffset.UTC), dto.getLastPlayed());
    assertEquals(7L, dto.getPlayCount());
    assertTrue(dto.getLikedByUser());
  }

  @Test
  void shouldDefaultNullableUserLibraryValues() {
    Song song = Song.builder().name("Song").fileHash("hash").build();
    UserLibrary entry =
        UserLibrary.builder().playCount(null).liked(null).isDeleted(false).build();

    SongDto dto = songMapper.toDto(song, entry);

    assertEquals(0L, dto.getPlayCount());
    assertFalse(dto.getLikedByUser());
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
