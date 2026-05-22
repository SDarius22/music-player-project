package com.example.musicplayerbackend.data;

import static org.assertj.core.api.Assertions.assertThat;

import com.example.musicplayerbackend.domain.VerificationCode;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

class VerificationCodeRepositoryTest extends BaseRepositoryTest {

  @Autowired VerificationCodeRepository verificationCodeRepository;

  @AfterEach
  void tearDown() {
    verificationCodeRepository.deleteAll();
  }

  private VerificationCode buildCode(String email, String code) {
    return VerificationCode.builder()
        .email(email)
        .code(code)
        .expiryDate(Instant.now().plus(10, ChronoUnit.MINUTES))
        .build();
  }

  @Test
  void shouldPersistVerificationCode() {
    VerificationCode saved =
        verificationCodeRepository.save(buildCode("user@example.com", "123456"));

    assertThat(saved.getId()).isNotNull().isPositive();
    assertThat(saved.getCode()).isEqualTo("123456");
  }

  @Test
  void shouldReturnCodeWhenEmailExists() {
    verificationCodeRepository.save(buildCode("code@example.com", "999888"));

    var found = verificationCodeRepository.findByEmail("code@example.com");

    assertThat(found).isPresent();
    assertThat(found.get().getCode()).isEqualTo("999888");
  }

  @Test
  void shouldReturnEmptyCodeWhenEmailNotFound() {
    var found = verificationCodeRepository.findByEmail("ghost@example.com");

    assertThat(found).isEmpty();
  }

  @Test
  void shouldRemoveVerificationCodeWhenDeletedById() {
    VerificationCode saved =
        verificationCodeRepository.save(buildCode("del@example.com", "111222"));
    verificationCodeRepository.deleteById(saved.getId());

    assertThat(verificationCodeRepository.findByEmail("del@example.com")).isEmpty();
  }

  @Test
  void shouldAllowMultipleCodesForSameEmail() {
    verificationCodeRepository.save(buildCode("multi@example.com", "aaa"));
    verificationCodeRepository.save(buildCode("multi@example.com", "bbb"));

    // VerificationCode has no unique constraint on email; the service deletes old codes first.
    assertThat(verificationCodeRepository.count()).isGreaterThanOrEqualTo(2);
  }
}
