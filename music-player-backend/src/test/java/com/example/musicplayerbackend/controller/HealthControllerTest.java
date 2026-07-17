package com.example.musicplayerbackend.controller;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;

import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

class HealthControllerTest {

  private final HealthController healthController = new HealthController();

  @Test
  void shouldReturnOkWithoutABody() {
    ResponseEntity<Void> response = healthController.healthCheck();

    assertEquals(HttpStatus.OK, response.getStatusCode());
    assertFalse(response.hasBody());
  }
}
