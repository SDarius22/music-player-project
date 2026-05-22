package com.example.musicplayerbackend.mapper;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

import com.example.musicplayerbackend.domain.Artist;
import com.example.musicplayerbackend.domain.ArtistDto;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.junit.jupiter.SpringExtension;

@ExtendWith(SpringExtension.class)
@Import({ArtistMapperImpl.class, SongMapperImpl.class})
class ArtistMapperTest {

  @Autowired ArtistMapper artistMapper;

  @Test
  void shouldMapArtistHashAndNameToDto() {
    Artist artist = Artist.builder().id(1L).hash("beatles-hash").name("The Beatles").build();

    ArtistDto dto = artistMapper.toDto(artist);

    assertEquals("beatles-hash", dto.getHash());
    assertEquals("The Beatles", dto.getName());
  }

  @Test
  void shouldReturnNullWhenArtistToDtoInputIsNull() {
    assertNull(artistMapper.toDto(null));
  }
}
