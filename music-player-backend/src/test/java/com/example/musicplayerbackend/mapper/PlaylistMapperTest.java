package com.example.musicplayerbackend.mapper;

import com.example.musicplayerbackend.data.projection.PlaylistListProjection;
import com.example.musicplayerbackend.domain.PlaylistDto;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.junit.jupiter.SpringExtension;

import static org.junit.jupiter.api.Assertions.*;

@ExtendWith(SpringExtension.class)
@Import(PlaylistMapperImpl.class)
class PlaylistMapperTest {

    @Autowired
    PlaylistMapper playlistMapper;

    @Test
    void shouldMapProjectionCoreFieldsAndIgnoreSongHashes() {
        PlaylistListProjection projection = new PlaylistListProjection() {
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
            public Boolean getHasCover() {
                return true;
            }

            @Override
            public String getSongFileHashesCsv() {
                return "a,b,c";
            }
        };

        PlaylistDto dto = playlistMapper.toDto(projection);

        assertEquals(42L, dto.getId());
        assertEquals("Road Trip", dto.getName());
        assertTrue(dto.getHasCover());
        assertNotNull(dto.getSongFileHashes());
        assertTrue(dto.getSongFileHashes().isEmpty());
    }

    @Test
    void shouldReturnNullWhenProjectionIsNull() {
        assertNull(playlistMapper.toDto(null));
    }
}

