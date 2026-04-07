package com.example.musicplayerbackend.helpers;

import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

import java.nio.charset.StandardCharsets;
import java.util.Base64;

import static org.junit.jupiter.api.Assertions.*;

class CoverDecoderTest {

    @Test
    void shouldDecodePlainBase64() {
        String encoded = Base64.getEncoder().encodeToString("cover-bytes".getBytes(StandardCharsets.UTF_8));

        byte[] decoded = CoverDecoder.decodeCoverImage(encoded);

        assertArrayEquals("cover-bytes".getBytes(StandardCharsets.UTF_8), decoded);
    }

    @Test
    void shouldDecodeDataUrlBase64() {
        String encoded = Base64.getEncoder().encodeToString("jpeg-data".getBytes(StandardCharsets.UTF_8));
        String dataUrl = "data:image/jpeg;base64," + encoded;

        byte[] decoded = CoverDecoder.decodeCoverImage(dataUrl);

        assertArrayEquals("jpeg-data".getBytes(StandardCharsets.UTF_8), decoded);
    }

    @Test
    void shouldThrowNotFoundForNullOrBlankInput() {
        ResponseStatusException exNull = assertThrows(ResponseStatusException.class,
                () -> CoverDecoder.decodeCoverImage(null));
        ResponseStatusException exBlank = assertThrows(ResponseStatusException.class,
                () -> CoverDecoder.decodeCoverImage("   "));

        assertEquals(HttpStatus.NOT_FOUND, exNull.getStatusCode());
        assertEquals(HttpStatus.NOT_FOUND, exBlank.getStatusCode());
    }

    @Test
    void shouldThrowNotFoundForInvalidBase64() {
        ResponseStatusException ex = assertThrows(ResponseStatusException.class,
                () -> CoverDecoder.decodeCoverImage("data:image/png;base64,###not-base64###"));

        assertEquals(HttpStatus.NOT_FOUND, ex.getStatusCode());
        assertEquals("Cover not found", ex.getReason());
    }
}

