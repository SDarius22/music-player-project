package com.example.musicplayerbackend.integration;

import com.example.musicplayerbackend.data.UserRepository;
import com.example.musicplayerbackend.data.VerificationCodeRepository;
import com.example.musicplayerbackend.domain.EmailRequest;
import com.example.musicplayerbackend.domain.RefreshAccessTokenRequest;
import com.example.musicplayerbackend.domain.VerificationCode;
import com.example.musicplayerbackend.domain.VerificationRequest;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.mail.Session;
import jakarta.mail.internet.MimeMessage;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.test.context.bean.override.mockito.MockitoBean;

import java.time.Instant;
import java.time.temporal.ChronoUnit;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doNothing;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class AuthControllerIntegrationTest extends BaseIntegrationTest {

    @MockitoBean
    JavaMailSender javaMailSender;

    @Autowired
    UserRepository userRepository;
    @Autowired
    VerificationCodeRepository verificationCodeRepository;
    @Autowired
    ObjectMapper objectMapper;

    @BeforeEach
    void setUpMail() {
        when(javaMailSender.createMimeMessage())
                .thenReturn(new MimeMessage((Session) null));
        doNothing().when(javaMailSender).send(any(MimeMessage.class));
    }

    @AfterEach
    void tearDown() {
        verificationCodeRepository.deleteAll();
        userRepository.deleteAll();
    }

    // ── send-code ─────────────────────────────────────────────────────────────

    @Test
    void shouldReturn200WhenSendingCode() throws Exception {
        EmailRequest req = new EmailRequest();
        req.setEmail("newuser@example.com");

        mockMvc.perform(post("/api/v1/auth/send-code")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isOk());
    }

    @Test
    void shouldUpdateCodeWhenSentTwice() throws Exception {
        EmailRequest req = new EmailRequest();
        req.setEmail("repeat@example.com");

        mockMvc.perform(post("/api/v1/auth/send-code")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isOk());

        mockMvc.perform(post("/api/v1/auth/send-code")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isOk());
    }

    // ── verify ────────────────────────────────────────────────────────────────

    @Test
    void shouldReturn200WithTokensWhenCodeIsValid() throws Exception {
        // First send the code so it gets persisted
        EmailRequest emailReq = new EmailRequest();
        emailReq.setEmail("verify@example.com");
        mockMvc.perform(post("/api/v1/auth/send-code")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(emailReq)))
                .andExpect(status().isOk());

        // Read the saved code directly
        String code = verificationCodeRepository.findByEmail("verify@example.com")
                .orElseThrow().getCode();

        VerificationRequest verifyReq = new VerificationRequest();
        verifyReq.setEmail("verify@example.com");
        verifyReq.setCode(code);

        mockMvc.perform(post("/api/v1/auth/verify")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(verifyReq)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken").isNotEmpty())
                .andExpect(jsonPath("$.refreshToken").isNotEmpty());
    }

    @Test
    void shouldReturn500WhenCodeIsWrong() throws Exception {
        EmailRequest emailReq = new EmailRequest();
        emailReq.setEmail("wrongcode@example.com");
        mockMvc.perform(post("/api/v1/auth/send-code")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(emailReq)))
                .andExpect(status().isOk());

        VerificationRequest verifyReq = new VerificationRequest();
        verifyReq.setEmail("wrongcode@example.com");
        verifyReq.setCode("000000");

        mockMvc.perform(post("/api/v1/auth/verify")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(verifyReq)))
                .andExpect(status().is5xxServerError());
    }

    // ── refresh ───────────────────────────────────────────────────────────────

    @Test
    void shouldReturn200WithNewTokenWhenRefreshTokenIsValid() throws Exception {
        // Get a valid refresh token by going through the full auth flow
        EmailRequest emailReq = new EmailRequest();
        emailReq.setEmail("refresh@example.com");
        mockMvc.perform(post("/api/v1/auth/send-code")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(emailReq)))
                .andExpect(status().isOk());

        String code = verificationCodeRepository.findByEmail("refresh@example.com")
                .orElseThrow().getCode();

        VerificationRequest verifyReq = new VerificationRequest();
        verifyReq.setEmail("refresh@example.com");
        verifyReq.setCode(code);

        String body = mockMvc.perform(post("/api/v1/auth/verify")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(verifyReq)))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();

        String refreshToken = objectMapper.readTree(body).get("refreshToken").asText();

        RefreshAccessTokenRequest refreshReq = new RefreshAccessTokenRequest();
        refreshReq.setRefreshToken(refreshToken);

        mockMvc.perform(post("/api/v1/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(refreshReq)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken").isNotEmpty());
    }

    @Test
    void shouldReturn500WhenNoCodeExists() throws Exception {
        VerificationRequest verifyReq = new VerificationRequest();
        verifyReq.setEmail("nocode@example.com");
        verifyReq.setCode("123456");

        mockMvc.perform(post("/api/v1/auth/verify")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(verifyReq)))
                .andExpect(status().is5xxServerError());
    }

    @Test
    void shouldReturn500WhenCodeIsExpired() throws Exception {
        // Create expired code directly in repo
        VerificationCode expired = VerificationCode.builder()
                .email("expired@example.com")
                .code("999999")
                .expiryDate(Instant.now().minus(1, ChronoUnit.HOURS))
                .build();
        verificationCodeRepository.save(expired);

        VerificationRequest verifyReq = new VerificationRequest();
        verifyReq.setEmail("expired@example.com");
        verifyReq.setCode("999999");

        mockMvc.perform(post("/api/v1/auth/verify")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(verifyReq)))
                .andExpect(status().is5xxServerError());
    }
}
