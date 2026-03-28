package com.example.musicplayerbackend.service;

import com.example.musicplayerbackend.data.UserRepository;
import com.example.musicplayerbackend.data.VerificationCodeRepository;
import com.example.musicplayerbackend.domain.*;
import com.example.musicplayerbackend.mapper.CodeMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Captor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class AuthServiceTest {

    @Mock
    UserRepository userRepository;
    @Mock
    VerificationCodeRepository codeRepository;
    @Mock
    JWTService jwtService;
    @Mock
    CodeMapper codeMapper;
    @Mock
    JavaMailSender mailSender;

    @Captor
    ArgumentCaptor<VerificationCode> vcCaptor;
    @Captor
    ArgumentCaptor<SimpleMailMessage> mailCaptor;

    AuthService service;

    @BeforeEach
    void setUp() {
        service = new AuthService(userRepository, codeRepository, jwtService, codeMapper, mailSender);
    }

    @Test
    void shouldSaveNewVerificationCodeAndSendMail() {
        when(codeRepository.findByEmail("a@b.com")).thenReturn(Optional.empty());
        when(codeRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        service.sendVerificationCode("a@b.com");

        verify(codeRepository).save(vcCaptor.capture());
        VerificationCode saved = vcCaptor.getValue();
        assertEquals("a@b.com", saved.getEmail());
        assertNotNull(saved.getCode());
        assertTrue(saved.getExpiryDate().isAfter(Instant.now()));

        verify(mailSender).send(mailCaptor.capture());
        assertEquals("a@b.com", mailCaptor.getValue().getTo()[0]);
    }

    @Test
    void shouldUpdateExistingVerificationCode() {
        VerificationCode existing = VerificationCode.builder()
                .email("a@b.com").code("123456")
                .expiryDate(Instant.now().minus(1, ChronoUnit.HOURS))
                .build();
        when(codeRepository.findByEmail("a@b.com")).thenReturn(Optional.of(existing));
        when(codeRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        service.sendVerificationCode("a@b.com");

        verify(codeRepository).save(vcCaptor.capture());
        assertSame(existing, vcCaptor.getValue()); // same object mutated
        assertNotEquals("123456", vcCaptor.getValue().getCode()); // code refreshed
        assertTrue(vcCaptor.getValue().getExpiryDate().isAfter(Instant.now()));
    }

    @Test
    void shouldThrowRuntimeExceptionWhenVerifyCodeEmailNotFound() {
        when(codeRepository.findByEmail("x@x.com")).thenReturn(Optional.empty());
        assertThrows(RuntimeException.class,
                () -> service.verifyCodeAndGenerateResponse("x@x.com", "111111"));
    }

    @Test
    void shouldThrowRuntimeExceptionWhenVerifyCodeIsExpired() {
        VerificationCode vc = VerificationCode.builder()
                .email("a@b.com").code("999999")
                .expiryDate(Instant.now().minus(1, ChronoUnit.MINUTES))
                .build();
        when(codeRepository.findByEmail("a@b.com")).thenReturn(Optional.of(vc));
        assertThrows(RuntimeException.class,
                () -> service.verifyCodeAndGenerateResponse("a@b.com", "999999"));
    }

    @Test
    void shouldThrowRuntimeExceptionWhenVerifyCodeIsWrong() {
        VerificationCode vc = VerificationCode.builder()
                .email("a@b.com").code("123456")
                .expiryDate(Instant.now().plus(10, ChronoUnit.MINUTES))
                .build();
        when(codeRepository.findByEmail("a@b.com")).thenReturn(Optional.of(vc));
        assertThrows(RuntimeException.class,
                () -> service.verifyCodeAndGenerateResponse("a@b.com", "000000"));
    }

    @Test
    void shouldCreateNewUserWhenVerifyCodeUserNotExists() {
        VerificationCode vc = VerificationCode.builder()
                .email("new@user.com").code("123456")
                .expiryDate(Instant.now().plus(10, ChronoUnit.MINUTES))
                .build();
        when(codeRepository.findByEmail("new@user.com")).thenReturn(Optional.of(vc));
        when(userRepository.findByEmail("new@user.com")).thenReturn(Optional.empty());
        User savedUser = User.builder().id(1L).email("new@user.com").role(Role.USER)
                .provider(AuthProvider.LOCAL).build();
        when(userRepository.save(any())).thenReturn(savedUser);
        when(jwtService.generateAccessToken(savedUser)).thenReturn("access");
        when(jwtService.generateRefreshToken(savedUser)).thenReturn("refresh");
        when(codeMapper.toAuthResponse("access", "refresh")).thenReturn(new AuthResponse());

        service.verifyCodeAndGenerateResponse("new@user.com", "123456");

        verify(userRepository).save(any(User.class));
        verify(codeRepository).delete(vc);
    }

    @Test
    void shouldUseExistingUserWhenVerifyingCode() {
        VerificationCode vc = VerificationCode.builder()
                .email("existing@user.com").code("654321")
                .expiryDate(Instant.now().plus(10, ChronoUnit.MINUTES))
                .build();
        User existingUser = User.builder().id(2L).email("existing@user.com").role(Role.USER)
                .provider(AuthProvider.LOCAL).build();
        when(codeRepository.findByEmail("existing@user.com")).thenReturn(Optional.of(vc));
        when(userRepository.findByEmail("existing@user.com")).thenReturn(Optional.of(existingUser));
        when(jwtService.generateAccessToken(existingUser)).thenReturn("acc");
        when(jwtService.generateRefreshToken(existingUser)).thenReturn("ref");
        when(codeMapper.toAuthResponse("acc", "ref")).thenReturn(new AuthResponse());

        service.verifyCodeAndGenerateResponse("existing@user.com", "654321");

        verify(userRepository, never()).save(any());
    }

    @Test
    void shouldReturnNewAccessTokenWhenRefreshTokenIsValid() {
        User user = User.builder().id(1L).email("a@b.com").role(Role.USER)
                .provider(AuthProvider.LOCAL).build();
        when(jwtService.extractUsername("old-refresh")).thenReturn("a@b.com");
        when(userRepository.findByEmail("a@b.com")).thenReturn(Optional.of(user));
        when(jwtService.isTokenValid("old-refresh", user)).thenReturn(true);
        when(jwtService.generateAccessToken(user)).thenReturn("new-access");
        when(codeMapper.toAuthResponse("new-access", "old-refresh")).thenReturn(new AuthResponse());

        service.refreshToken("old-refresh");

        verify(jwtService).generateAccessToken(user);
    }

    @Test
    void shouldThrowWhenRefreshTokenIsInvalid() {
        User user = User.builder().id(1L).email("a@b.com").role(Role.USER)
                .provider(AuthProvider.LOCAL).build();
        when(jwtService.extractUsername("bad-token")).thenReturn("a@b.com");
        when(userRepository.findByEmail("a@b.com")).thenReturn(Optional.of(user));
        when(jwtService.isTokenValid("bad-token", user)).thenReturn(false);

        assertThrows(RuntimeException.class, () -> service.refreshToken("bad-token"));
    }

    @Test
    void shouldThrowWhenRefreshTokenEmailIsNull() {
        when(jwtService.extractUsername("no-user")).thenReturn(null);
        assertThrows(RuntimeException.class, () -> service.refreshToken("no-user"));
    }
}
