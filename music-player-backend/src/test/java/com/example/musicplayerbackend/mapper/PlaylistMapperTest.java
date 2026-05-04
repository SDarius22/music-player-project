package com.example.musicplayerbackend.mapper;

import com.example.musicplayerbackend.data.projection.PlaylistListProjection;
import com.example.musicplayerbackend.domain.Playlist;
import com.example.musicplayerbackend.domain.PlaylistDetailDto;
import com.example.musicplayerbackend.domain.PlaylistDto;
import com.example.musicplayerbackend.domain.PlaylistSongDto;
import com.example.musicplayerbackend.domain.SongDto;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.junit.jupiter.SpringExtension;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

@ExtendWith(SpringExtension.class)
@Import(PlaylistMapperImpl.class)
class PlaylistMapperTest {

    @Autowired
    PlaylistMapper playlistMapper;

    @Test
    void shouldMapProjectionIncludingSongHashesFromCsv() {
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
    void shouldMapPlaylistDetailDtoWithSongs() {
        Playlist playlist = Playlist.builder()
                .id(11L)
                .name("Focus")
                .coverImage("base64-image")
                .build();
        SongDto songDto = new SongDto();
        songDto.setName("Track 1");
        PlaylistSongDto entry = new PlaylistSongDto();
        entry.setSong(songDto);
        entry.setPosition(0);

        PlaylistDetailDto dto = playlistMapper.toDetailDto(playlist, List.of(entry));

        assertEquals(11L, dto.getId());
        assertEquals("Focus", dto.getName());
        assertEquals(1, dto.getPlaylistSongs().size());
        assertEquals(0, dto.getPlaylistSongs().getFirst().getPosition());
        assertEquals("Track 1", dto.getPlaylistSongs().getFirst().getSong().getName());
    }

    @Test
    void shouldReturnNullWhenProjectionIsNull() {
        assertNull(playlistMapper.toDto(null));
    }
}
