package com.example.musicplayerbackend.mapper;

import com.example.musicplayerbackend.domain.Artist;
import com.example.musicplayerbackend.domain.ArtistDto;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.junit.jupiter.SpringExtension;

import static org.junit.jupiter.api.Assertions.*;

@ExtendWith(SpringExtension.class)
@Import(ArtistMapperImpl.class)
class ArtistMapperTest {

    @Autowired ArtistMapper artistMapper;

    @Test
    void shouldMapArtistIdAndNameToDto() {
        Artist artist = Artist.builder().id(1L).name("The Beatles").build();

        ArtistDto dto = artistMapper.toDto(artist);

        assertEquals(1L, dto.getId());
        assertEquals("The Beatles", dto.getName());
    }

    @Test
    void shouldReturnNullWhenArtistToDtoInputIsNull() {
        assertNull(artistMapper.toDto(null));
    }

    @Test
    void shouldMapArtistIdAndNameToEntity() {
        ArtistDto dto = new ArtistDto();
        dto.setId(2L);
        dto.setName("Led Zeppelin");

        Artist entity = artistMapper.toEntity(dto);

        assertEquals(2L, entity.getId());
        assertEquals("Led Zeppelin", entity.getName());
    }

    @Test
    void shouldReturnNullWhenArtistToEntityInputIsNull() {
        assertNull(artistMapper.toEntity(null));
    }
}
