package com.example.musicplayerbackend.mapper;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

import com.example.musicplayerbackend.data.projection.PlaylistListProjection;
import com.example.musicplayerbackend.domain.PlaylistDto;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.junit.jupiter.SpringExtension;

@ExtendWith(SpringExtension.class)
@Import(PlaylistMapperImpl.class)
class PlaylistMapperTest {

  @Autowired PlaylistMapper playlistMapper;

  @Test
  void shouldMapProjectionIncludingSongHashesFromCsv() {
    PlaylistListProjection projection =
        new PlaylistListProjection() {
          @Override
          public Long getId() {
            return 42L;
          }

          @Override
          public String getName() {
            return "Road Trip";
          }

          @Override
          public String getType() {
            return "USER";
          }

          @Override
          public Long getUserId() {
            return 5L;
          }

          @Override
          public Boolean getIndestructible() {
            return false;
          }

          @Override
          public String getSongFileHashesCsv() {
            return "a,b,c";
          }
        };

    PlaylistDto dto = playlistMapper.toDto(projection);

    assertEquals(42L, dto.getId());
    assertEquals("Road Trip", dto.getName());
    assertEquals(List.of("a", "b", "c"), dto.getSongFileHashes());
  }

  @Test
  void shouldReturnNullWhenProjectionIsNull() {
    assertNull(playlistMapper.toDto(null));
  }
}
