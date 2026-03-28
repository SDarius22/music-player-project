package com.example.musicplayerbackend.service;

import com.example.musicplayerbackend.domain.AuthProvider;
import com.example.musicplayerbackend.domain.Role;
import com.example.musicplayerbackend.domain.User;
import io.jsonwebtoken.ExpiredJwtException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.time.Instant;

import static org.junit.jupiter.api.Assertions.*;

class JWTServiceTest {

    private JWTService jwtService;

    private User testUser;

    @BeforeEach
    void setUp() throws Exception {
        jwtService = new JWTService();

        var secretKeyField = JWTService.class.getDeclaredField("secretKey");
        secretKeyField.setAccessible(true);
        secretKeyField.set(jwtService, "404E635266556A586E3272357538782F413F4428472B4B6250645367566B5970");

        var expirationField = JWTService.class.getDeclaredField("jwtExpiration");
        expirationField.setAccessible(true);
        expirationField.setLong(jwtService, 900_000L); // 15 min

        var refreshExpirationField = JWTService.class.getDeclaredField("refreshExpiration");
        refreshExpirationField.setAccessible(true);
        refreshExpirationField.setLong(jwtService, 2_592_000_000L); // 30 days

        testUser = User.builder()
                .id(1L)
                .email("test@example.com")
                .role(Role.USER)
                .provider(AuthProvider.LOCAL)
                .createdAt(Instant.now())
                .build();
    }

    @Test
    void shouldProduceNonNullAccessToken() {
        String token = jwtService.generateAccessToken(testUser);
        assertNotNull(token);
        assertFalse(token.isBlank());
    }

    @Test
    void shouldReturnUserEmailFromToken() {
        String token = jwtService.generateAccessToken(testUser);
        assertEquals("test@example.com", jwtService.extractUsername(token));
    }

    @Test
    void shouldExtractCorrectUsernameFromRefreshToken() {
        String token = jwtService.generateRefreshToken(testUser);
        assertEquals("test@example.com", jwtService.extractUsername(token));
    }

    @Test
    void shouldReturnTrueForFreshAccessToken() {
        String token = jwtService.generateAccessToken(testUser);
        assertTrue(jwtService.isTokenValid(token, testUser));
    }

    @Test
    void shouldReturnFalseForWrongUser() {
        User other = User.builder()
                .id(2L)
                .email("other@example.com")
                .role(Role.USER)
                .provider(AuthProvider.LOCAL)
                .build();
        String token = jwtService.generateAccessToken(testUser);
        assertFalse(jwtService.isTokenValid(token, other));
    }

    @Test
    void shouldReturnTrueForFreshRefreshToken() {
        String token = jwtService.generateRefreshToken(testUser);
        assertTrue(jwtService.isTokenValid(token, testUser));
    }

    @Test
    void shouldReturnFalseForExpiredToken() throws Exception {
        // Override expiration to 1ms
        var expirationField = JWTService.class.getDeclaredField("jwtExpiration");
        expirationField.setAccessible(true);
        expirationField.setLong(jwtService, 1L);

        String token = jwtService.generateAccessToken(testUser);
        Thread.sleep(5); // Let the token expire
        assertThrows(ExpiredJwtException.class, () -> jwtService.isTokenValid(token, testUser));
    }

    @Test
    void shouldProduceValidTokenForAdminUser() {
        User admin = User.builder()
                .id(99L)
                .email("admin@example.com")
                .role(Role.ADMIN)
                .provider(AuthProvider.LOCAL)
                .build();
        String token = jwtService.generateAccessToken(admin);
        assertTrue(jwtService.isTokenValid(token, admin));
        assertEquals("admin@example.com", jwtService.extractUsername(token));
    }
}
