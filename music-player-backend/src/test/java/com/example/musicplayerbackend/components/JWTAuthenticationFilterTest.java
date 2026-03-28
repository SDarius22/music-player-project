package com.example.musicplayerbackend.components;

import com.example.musicplayerbackend.service.JWTService;
import jakarta.servlet.FilterChain;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;

import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class JWTAuthenticationFilterTest {

    @Mock JWTService jwtService;
    @Mock UserDetailsService userDetailsService;
    @Mock HttpServletRequest request;
    @Mock HttpServletResponse response;
    @Mock FilterChain filterChain;
    @Mock UserDetails userDetails;

    @InjectMocks
    JWTAuthenticationFilter filter;

    @BeforeEach
    void clearSecurityContext() {
        SecurityContextHolder.clearContext();
    }

    @AfterEach
    void cleanup() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void shouldPassThroughWithoutAuthenticationWhenNoAuthorizationHeader() throws Exception {
        when(request.getHeader("Authorization")).thenReturn(null);

        filter.doFilterInternal(request, response, filterChain);

        verify(filterChain).doFilter(request, response);
        verify(jwtService, never()).extractUsername(any());
    }

    @Test
    void shouldPassThroughWithoutAuthenticationWhenNonBearerAuthorizationHeader() throws Exception {
        when(request.getHeader("Authorization")).thenReturn("Basic dXNlcjpwYXNz");

        filter.doFilterInternal(request, response, filterChain);

        verify(filterChain).doFilter(request, response);
        verify(jwtService, never()).extractUsername(any());
    }

    @Test
    void shouldSetAuthenticationWhenBearerTokenIsValid() throws Exception {
        when(request.getHeader("Authorization")).thenReturn("Bearer valid-jwt-token");
        when(jwtService.extractUsername("valid-jwt-token")).thenReturn("user@example.com");
        when(userDetailsService.loadUserByUsername("user@example.com")).thenReturn(userDetails);
        when(jwtService.isTokenValid("valid-jwt-token", userDetails)).thenReturn(true);
        when(userDetails.getAuthorities()).thenReturn(java.util.List.of());

        filter.doFilterInternal(request, response, filterChain);

        verify(filterChain).doFilter(request, response);
        verify(userDetailsService).loadUserByUsername("user@example.com");
        verify(jwtService).isTokenValid("valid-jwt-token", userDetails);
        // authentication should now be set
        assert SecurityContextHolder.getContext().getAuthentication() != null;
    }

    @Test
    void shouldSkipAuthenticationWhenExtractedEmailIsNull() throws Exception {
        when(request.getHeader("Authorization")).thenReturn("Bearer some-token");
        when(jwtService.extractUsername("some-token")).thenReturn(null);

        filter.doFilterInternal(request, response, filterChain);

        verify(filterChain).doFilter(request, response);
        verify(userDetailsService, never()).loadUserByUsername(any());
    }

    @Test
    void shouldSkipReAuthenticationWhenAlreadyAuthenticated() throws Exception {
        when(request.getHeader("Authorization")).thenReturn("Bearer already-authed");
        when(jwtService.extractUsername("already-authed")).thenReturn("user@example.com");

        // Pre-set authentication in context
        Authentication existingAuth = mock(Authentication.class);
        SecurityContextHolder.getContext().setAuthentication(existingAuth);

        filter.doFilterInternal(request, response, filterChain);

        verify(filterChain).doFilter(request, response);
        verify(userDetailsService, never()).loadUserByUsername(any());
    }

    @Test
    void shouldNotSetAuthenticationWhenBearerTokenIsInvalid() throws Exception {
        when(request.getHeader("Authorization")).thenReturn("Bearer invalid-token");
        when(jwtService.extractUsername("invalid-token")).thenReturn("user@example.com");
        when(userDetailsService.loadUserByUsername("user@example.com")).thenReturn(userDetails);
        when(jwtService.isTokenValid("invalid-token", userDetails)).thenReturn(false);

        filter.doFilterInternal(request, response, filterChain);

        verify(filterChain).doFilter(request, response);
        assert SecurityContextHolder.getContext().getAuthentication() == null;
    }
}
