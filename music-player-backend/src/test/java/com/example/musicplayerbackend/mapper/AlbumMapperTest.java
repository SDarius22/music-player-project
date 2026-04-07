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
                .hash("album-hash")
                .name("Abbey Road")
                .coverImage("base64data")
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
    void shouldMapAlbumHashAndNameToEntity() {
        AlbumDto dto = new AlbumDto();
        dto.setHash("help-hash");
        dto.setName("Help!");

        Album entity = albumMapper.toEntity(dto);

        assertEquals("help-hash", entity.getHash());
        assertEquals("Help!", entity.getName());
    }

    @Test
    void shouldReturnNullWhenAlbumToEntityInputIsNull() {
        assertNull(albumMapper.toEntity(null));
    }
}
