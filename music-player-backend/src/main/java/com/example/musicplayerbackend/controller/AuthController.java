package com.example.musicplayerbackend.controller;

import com.example.musicplayerbackend.domain.AuthResponse;
import com.example.musicplayerbackend.domain.EmailRequest;
import com.example.musicplayerbackend.domain.VerificationRequest;
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
}