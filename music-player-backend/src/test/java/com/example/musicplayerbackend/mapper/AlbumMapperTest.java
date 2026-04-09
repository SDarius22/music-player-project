package com.example.musicplayerbackend.mapper;

import com.example.musicplayerbackend.data.projection.AlbumListProjection;
import com.example.musicplayerbackend.domain.Album;
import com.example.musicplayerbackend.domain.AlbumDto;
import com.example.musicplayerbackend.domain.AlbumExpandedDto;
import com.example.musicplayerbackend.domain.Artist;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.junit.jupiter.SpringExtension;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

@ExtendWith(SpringExtension.class)
@Import(AlbumMapperImpl.class)
class AlbumMapperTest {

    @Autowired
    AlbumMapper albumMapper;

    @Test
    void shouldMapAllFieldsToDto() {
        Artist artistA = Artist.builder().hash("a-hash").name("A Artist").build();
        Artist artistB = Artist.builder().hash("b-hash").name("B Artist").build();
        Album album = Album.builder()
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
    void shouldMapAlbumHashAndNameToEntity() {
        AlbumDto dto = new AlbumDto();
        dto.setHash("help-hash");
        dto.setName("Help!");

        Album entity = albumMapper.toEntity(dto);

        assertEquals("help-hash", entity.getHash());
        assertEquals("Help!", entity.getName());
    }

    @Test
    void shouldMapProjectionToExpandedDtoWithoutArtists() {
        AlbumListProjection projection = mock(AlbumListProjection.class);
        when(projection.getHash()).thenReturn("album-hash");
        when(projection.getName()).thenReturn("Album Name");

        AlbumExpandedDto dto = albumMapper.toExpandedDto(projection);

        assertEquals("album-hash", dto.getHash());
        assertEquals("Album Name", dto.getName());
        assertNull(dto.getArtist());
    }

    @Test
    void shouldReturnNullWhenAlbumToEntityInputIsNull() {
        assertNull(albumMapper.toEntity(null));
    }
}
