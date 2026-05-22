package com.example.musicplayerbackend.mapper;

import static org.junit.jupiter.api.Assertions.*;

import com.example.musicplayerbackend.domain.AuthResponse;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.junit.jupiter.SpringExtension;

@ExtendWith(SpringExtension.class)
@Import(CodeMapperImpl.class)
class CodeMapperTest {

  @Autowired CodeMapper codeMapper;

  @Test
  void shouldMapBothTokensToAuthResponse() {
    AuthResponse response = codeMapper.toAuthResponse("access-token-123", "refresh-token-456");

    assertEquals("access-token-123", response.getAccessToken());
    assertEquals("refresh-token-456", response.getRefreshToken());
  }

  @Test
  void shouldReturnNullWhenBothAuthResponseTokensAreNull() {
    AuthResponse response = codeMapper.toAuthResponse(null, null);

    assertNull(response);
  }

  @Test
  void shouldMapRefreshTokenWhenAccessTokenIsNull() {
    AuthResponse response = codeMapper.toAuthResponse(null, "refresh-only");

    assertNotNull(response);
    assertNull(response.getAccessToken());
    assertEquals("refresh-only", response.getRefreshToken());
  }

  @Test
  void shouldMapAccessTokenWhenRefreshTokenIsNull() {
    AuthResponse response = codeMapper.toAuthResponse("access-only", null);

    assertNotNull(response);
    assertEquals("access-only", response.getAccessToken());
    assertNull(response.getRefreshToken());
  }
}
