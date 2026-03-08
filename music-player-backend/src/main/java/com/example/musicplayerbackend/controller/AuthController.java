package com.example.musicplayerbackend.controller;

import com.example.musicplayerbackend.domain.*;
import com.example.musicplayerbackend.service.AuthService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class AuthController implements AuthApi {

    private final AuthService authService;

    @Override
    public ResponseEntity<Void> sendVerificationCode(EmailRequest emailRequest) {
        authService.sendVerificationCode(emailRequest.getEmail());
        return ResponseEntity.ok().build();
    }

    @Override
    public ResponseEntity<AuthResponse> verifyAuthenticationCode(VerificationRequest verificationRequest) {
        return ResponseEntity.ok(authService.verifyCodeAndGenerateResponse(verificationRequest.getEmail(), verificationRequest.getCode()));
    }

    @Override
    public ResponseEntity<AuthResponse> googleOAuthLogin(GoogleOAuthLoginRequest googleOAuthLoginRequest) {
        return ResponseEntity.ok(authService.loginWithGoogle(googleOAuthLoginRequest.getIdToken()));
    }

    @Override
    public ResponseEntity<AuthResponse> refreshAccessToken(RefreshAccessTokenRequest refreshAccessTokenRequest) {
        return ResponseEntity.ok(authService.refreshToken(refreshAccessTokenRequest.getRefreshToken()));
    }
}