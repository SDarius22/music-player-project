package com.example.musicplayerbackend.mapper;

import com.example.musicplayerbackend.domain.Album;
import com.example.musicplayerbackend.domain.AlbumDto;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.junit.jupiter.SpringExtension;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

@ExtendWith(SpringExtension.class)
@Import(AlbumMapperImpl.class)
class AlbumMapperTest {

    @Autowired
    AlbumMapper albumMapper;

    @Test
    void shouldMapAllFieldsToDto() {
        Album album = Album.builder()
                .id(1L)
                .name("Abbey Road")
                .coverImage("base64data")
                .build();

        AlbumDto dto = albumMapper.toDto(album);

        assertEquals(1L, dto.getId());
        assertEquals("Abbey Road", dto.getName());
    }

    @Test
    void shouldReturnNullWhenAlbumToDtoInputIsNull() {
        assertNull(albumMapper.toDto(null));
    }

    @Test
    void shouldMapIdAndNameWhenCoverImageIsNull() {
        Album album = Album.builder().id(2L).name("No Cover").build();

        AlbumDto dto = albumMapper.toDto(album);

        assertEquals(2L, dto.getId());
        assertEquals("No Cover", dto.getName());
    }

    @Test
    void shouldMapAlbumIdAndNameToEntity() {
        AlbumDto dto = new AlbumDto();
        dto.setId(5L);
        dto.setName("Help!");

        Album entity = albumMapper.toEntity(dto);

        assertEquals(5L, entity.getId());
        assertEquals("Help!", entity.getName());
    }

    @Test
    void shouldReturnNullWhenAlbumToEntityInputIsNull() {
        assertNull(albumMapper.toEntity(null));
    }
}
