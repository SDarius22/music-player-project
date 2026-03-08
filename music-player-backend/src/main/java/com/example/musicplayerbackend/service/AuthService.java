package com.example.musicplayerbackend.service;

import com.example.musicplayerbackend.data.UserRepository;
import com.example.musicplayerbackend.data.VerificationCodeRepository;
import com.example.musicplayerbackend.domain.*;
import com.example.musicplayerbackend.mapper.CodeMapper;
import com.google.api.client.googleapis.auth.oauth2.GoogleIdToken;
import com.google.api.client.googleapis.auth.oauth2.GoogleIdTokenVerifier;
import com.google.api.client.http.javanet.NetHttpTransport;
import com.google.api.client.json.gson.GsonFactory;
import lombok.RequiredArgsConstructor;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Collections;
import java.util.Random;

@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository userRepository;
    private final VerificationCodeRepository codeRepository;
    private final JWTService jwtService;
    private final CodeMapper codeMapper;
    private final JavaMailSender mailSender;

    public void sendVerificationCode(String email) {
        String code = String.valueOf(new Random().nextInt(900000) + 100000);
        VerificationCode vc = codeRepository.findByEmail(email)
                .orElse(VerificationCode.builder().email(email).build());

        vc.setCode(code);
        vc.setExpiryDate(Instant.now().plus(30, ChronoUnit.MINUTES));
        codeRepository.save(vc);

        SimpleMailMessage message = new SimpleMailMessage();
        message.setFrom("darius.sala@bt-app.com");
        message.setTo(email);
        message.setSubject("Your Login Code");
        message.setText("Your code is: " + code);
        mailSender.send(message);
    }

    public AuthResponse loginWithGoogle(String idTokenString) {
        GoogleIdTokenVerifier verifier = new GoogleIdTokenVerifier.Builder(new NetHttpTransport(), new GsonFactory())
                .setAudience(Collections.singletonList("YOUR_GOOGLE_CLIENT_ID_FROM_FLUTTER"))
                .build();

        try {
            GoogleIdToken idToken = verifier.verify(idTokenString);
            if (idToken != null) {
                GoogleIdToken.Payload payload = idToken.getPayload();
                String email = payload.getEmail();

                User user = userRepository.findByEmail(email)
                        .orElseGet(() -> userRepository.save(User.builder()
                                .email(email)
                                .role(Role.USER)
                                .provider(AuthProvider.GOOGLE)
                                .build()));

                return codeMapper.toAuthResponse(jwtService.generateAccessToken(user), jwtService.generateRefreshToken(user));
            } else {
                throw new RuntimeException("Invalid ID token");
            }
        } catch (Exception e) {
            throw new RuntimeException("Google Auth Failed", e);
        }
    }

    public AuthResponse verifyCodeAndGenerateResponse(String email, String code) {
        VerificationCode vc = codeRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("Invalid email"));

        if (vc.getExpiryDate().isBefore(Instant.now())) {
            throw new RuntimeException("Code expired");
        }

        if (!vc.getCode().equals(code)) {
            throw new RuntimeException("Invalid code");
        }

        codeRepository.delete(vc);

        User user = userRepository.findByEmail(email)
                .orElseGet(() -> {
                    User newUser = User.builder()
                            .email(email)
                            .createdAt(Instant.now())
                            .build();
                    return userRepository.save(newUser);
                });

        return codeMapper.toAuthResponse(jwtService.generateAccessToken(user), jwtService.generateRefreshToken(user));
    }

    public AuthResponse refreshToken(String refreshToken) {
        String email = jwtService.extractUsername(refreshToken);
        if (email != null) {
            User user = userRepository.findByEmail(email).orElseThrow();

            if (jwtService.isTokenValid(refreshToken, user)) {
                String newAccessToken = jwtService.generateAccessToken(user);
                return codeMapper.toAuthResponse(newAccessToken, refreshToken);
            }
        }
        throw new RuntimeException("Invalid Refresh Token");
    }
}