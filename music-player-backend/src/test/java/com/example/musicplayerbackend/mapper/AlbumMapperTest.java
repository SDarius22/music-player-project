package com.example.musicplayerbackend.mapper;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

import com.example.musicplayerbackend.domain.Album;
import com.example.musicplayerbackend.domain.AlbumDto;
import com.example.musicplayerbackend.domain.AlbumExpandedDto;
import com.example.musicplayerbackend.domain.Artist;
import com.example.musicplayerbackend.domain.ContentType;
import com.example.musicplayerbackend.domain.Song;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.junit.jupiter.SpringExtension;

@ExtendWith(SpringExtension.class)
@Import({AlbumMapperImpl.class, ArtistMapperImpl.class, SongMapperImpl.class})
class AlbumMapperTest {

  @Autowired AlbumMapper albumMapper;

  @Test
  void shouldMapAllFieldsToDto() {
    Artist artistA = Artist.builder().hash("a-hash").name("A Artist").build();
    Artist artistB = Artist.builder().hash("b-hash").name("B Artist").build();
    Album album =
        Album.builder()
            .id(1L)
            .hash("album-hash")
            .name("Abbey Road")
            .coverImage("base64data")
            .artists(java.util.Set.of(artistB, artistA))
            .build();

    AlbumDto dto = albumMapper.toDto(album);

    assertEquals("album-hash", dto.getHash());
    assertEquals("Abbey Road", dto.getName());
  }

  @Test
  void shouldReturnNullWhenAlbumToDtoInputIsNull() {
    assertNull(albumMapper.toDto(null));
  }

  @Test
  void shouldMapIdAndNameWhenCoverImageIsNull() {
    Album album = Album.builder().id(2L).hash("no-cover-hash").name("No Cover").build();

    AlbumDto dto = albumMapper.toDto(album);

    assertEquals("no-cover-hash", dto.getHash());
    assertEquals("No Cover", dto.getName());
  }

  @Test
  void shouldMapAlbumAndMainArtistToExpandedDto() {
    Artist mainArtist = Artist.builder().hash("artist-hash").name("Artist Name").build();
    Song songA =
        Song.builder()
            .name("Track A")
            .fileHash("hash-a")
            .songType(ContentType.STREAMABLE)
            .artist(mainArtist)
            .build();
    Song songB =
        Song.builder()
            .name("Track B")
            .fileHash("hash-b")
            .songType(ContentType.STREAMABLE)
            .artist(mainArtist)
            .build();
    Album album =
        Album.builder().hash("album-hash").name("Album Name").songs(List.of(songA, songB)).build();

    AlbumExpandedDto dto = albumMapper.toExpandedDto(album, mainArtist);

    assertEquals("album-hash", dto.getHash());
    assertEquals("Album Name", dto.getName());
    assertEquals("artist-hash", dto.getArtist().getHash());
    assertEquals("Artist Name", dto.getArtist().getName());
    assertEquals(List.of("hash-a", "hash-b"), dto.getSongFileHashes());
  }
}
