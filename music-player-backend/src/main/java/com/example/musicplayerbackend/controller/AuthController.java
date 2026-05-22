package com.example.musicplayerbackend.controller;

import com.example.musicplayerbackend.domain.AuthResponse;
import com.example.musicplayerbackend.domain.EmailRequest;
import com.example.musicplayerbackend.domain.RefreshAccessTokenRequest;
import com.example.musicplayerbackend.domain.VerificationRequest;
import com.example.musicplayerbackend.service.AuthService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@Slf4j
@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class AuthController implements AuthApi {

  private final AuthService authService;

  @Override
  public ResponseEntity<Void> sendVerificationCode(EmailRequest emailRequest) {
    log.info("[AUTH] Verification code requested for email={}", emailRequest.getEmail());
    authService.sendVerificationCode(emailRequest.getEmail());
    return ResponseEntity.ok().build();
  }

  @Override
  public ResponseEntity<AuthResponse> verifyAuthenticationCode(
      VerificationRequest verificationRequest) {
    log.info("[AUTH] Code verification attempt for email={}", verificationRequest.getEmail());
    return ResponseEntity.ok(
        authService.verifyCodeAndGenerateResponse(
            verificationRequest.getEmail(), verificationRequest.getCode()));
  }

  @Override
  public ResponseEntity<AuthResponse> refreshAccessToken(
      RefreshAccessTokenRequest refreshAccessTokenRequest) {
    log.info("[AUTH] Token refresh requested");
    return ResponseEntity.ok(authService.refreshToken(refreshAccessTokenRequest.getRefreshToken()));
  }
}
