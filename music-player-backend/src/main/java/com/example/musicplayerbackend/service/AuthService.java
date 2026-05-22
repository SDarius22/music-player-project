package com.example.musicplayerbackend.service;

import com.example.musicplayerbackend.data.UserRepository;
import com.example.musicplayerbackend.data.VerificationCodeRepository;
import com.example.musicplayerbackend.domain.AuthProvider;
import com.example.musicplayerbackend.domain.AuthResponse;
import com.example.musicplayerbackend.domain.Role;
import com.example.musicplayerbackend.domain.User;
import com.example.musicplayerbackend.domain.VerificationCode;
import com.example.musicplayerbackend.mapper.CodeMapper;
import jakarta.mail.MessagingException;
import java.security.SecureRandom;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class AuthService {

  private static final long VERIFICATION_CODE_TTL_MINUTES = 30;
  private static final SecureRandom VERIFICATION_CODE_RANDOM = new SecureRandom();

  private final UserRepository userRepository;
  private final VerificationCodeRepository codeRepository;
  private final JWTService jwtService;
  private final CodeMapper codeMapper;
  private final JavaMailSender mailSender;
  private final DefaultPlaylistService defaultPlaylistService;

  @Value("${spring.mail.username}")
  private String emailUsername;

  public void sendVerificationCode(String email) {
    String code = String.valueOf(VERIFICATION_CODE_RANDOM.nextInt(900000) + 100000);
    VerificationCode vc =
        codeRepository.findByEmail(email).orElse(VerificationCode.builder().email(email).build());

    vc.setCode(code);
    vc.setExpiryDate(Instant.now().plus(VERIFICATION_CODE_TTL_MINUTES, ChronoUnit.MINUTES));
    codeRepository.save(vc);

    try {
      var message = mailSender.createMimeMessage();
      var helper = new MimeMessageHelper(message, true, "UTF-8");
      helper.setFrom(emailUsername);
      helper.setTo(email);
      helper.setSubject("Your Login Code");
      helper.setText(buildPlainTextCodeEmail(code), buildHtmlCodeEmail(code));
      mailSender.send(message);
    } catch (MessagingException exception) {
      throw new RuntimeException("Failed to send verification email", exception);
    }
  }

  private String buildPlainTextCodeEmail(String code) {
    return "Hi,\n\n"
        + "Use this verification code to sign in:\n\n"
        + "  "
        + code
        + "\n\n"
        + "This code expires in "
        + VERIFICATION_CODE_TTL_MINUTES
        + " minutes.\n\n"
        + "If you did not request this, you can safely ignore this email.\n";
  }

  private String buildHtmlCodeEmail(String code) {
    return """
    <div style="font-family: Arial, sans-serif; color: #222; line-height: 1.5;">
      <h2 style="margin-bottom: 8px;">Your Login Code</h2>
      <p style="margin-top: 0;">Use this verification code to sign in:</p>
      <div style="display: inline-block; background: #f3f4f6; border: 1px solid #d1d5db; border-radius: 8px; padding: 12px 20px; margin: 8px 0 12px; font-size: 24px; font-weight: 700; letter-spacing: 4px;">%s</div>
      <p style="margin: 0;">This code expires in <strong>%d minutes</strong>.</p>
      <p style="margin-top: 12px; color: #555;">If you did not request this, you can safely ignore this email.</p>
    </div>
    """
        .formatted(code, VERIFICATION_CODE_TTL_MINUTES);
  }

  public AuthResponse verifyCodeAndGenerateResponse(String email, String code) {
    VerificationCode vc =
        codeRepository.findByEmail(email).orElseThrow(() -> new RuntimeException("Invalid email"));

    if (vc.getExpiryDate().isBefore(Instant.now())) {
      throw new RuntimeException("Code expired");
    }

    if (!vc.getCode().equals(code)) {
      throw new RuntimeException("Invalid code");
    }

    codeRepository.delete(vc);

    User user =
        userRepository
            .findByEmail(email)
            .orElseGet(
                () -> {
                  User newUser =
                      User.builder()
                          .email(email)
                          .createdAt(Instant.now())
                          .role(Role.USER)
                          .provider(AuthProvider.LOCAL)
                          .build();
                  return userRepository.save(newUser);
                });

    defaultPlaylistService.provisionDefaultPlaylists(user);

    return codeMapper.toAuthResponse(
        jwtService.generateAccessToken(user), jwtService.generateRefreshToken(user));
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
