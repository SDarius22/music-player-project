package com.example.musicplayerbackend.service;

import com.example.musicplayerbackend.data.UserRepository;
import com.example.musicplayerbackend.data.VerificationCodeRepository;
import com.example.musicplayerbackend.domain.AuthResponse;
import com.example.musicplayerbackend.domain.User;
import com.example.musicplayerbackend.domain.VerificationCode;
import com.example.musicplayerbackend.mapper.CodeMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
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
        vc.setExpiryDate(Instant.now().plus(30, ChronoUnit.MINUTES)); // Valid for 5 mins
        codeRepository.save(vc);

        SimpleMailMessage message = new SimpleMailMessage();
        message.setFrom("darius.sala@bt-app.com");
        message.setTo(email);
        message.setSubject("Your Login Code");
        message.setText("Your code is: " + code);
        mailSender.send(message);
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

        return codeMapper.toAuthResponse(jwtService.generateToken(user));
    }
}