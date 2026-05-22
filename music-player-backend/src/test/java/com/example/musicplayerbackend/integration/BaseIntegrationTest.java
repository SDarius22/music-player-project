package com.example.musicplayerbackend.integration;

import com.example.musicplayerbackend.components.SignalingHandler;
import com.example.musicplayerbackend.domain.AuthProvider;
import com.example.musicplayerbackend.domain.Role;
import com.example.musicplayerbackend.domain.User;
import java.time.Instant;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.containers.PostgreSQLContainer;

@SpringBootTest(
    webEnvironment = SpringBootTest.WebEnvironment.MOCK,
    properties = {"MAIL_HOST=localhost", "MAIL_USER=test@example.com", "MAIL_PASSWORD=test"})
@AutoConfigureMockMvc
public abstract class BaseIntegrationTest {

  @SuppressWarnings("resource")
  private static final PostgreSQLContainer<?> POSTGRES =
      new PostgreSQLContainer<>("postgres:18").withReuse(true);

  @SuppressWarnings("resource")
  private static final GenericContainer<?> REDIS =
      new GenericContainer<>("redis:7-alpine").withExposedPorts(6379).withReuse(true);

  static {
    POSTGRES.start();
    REDIS.start();
  }

  @Autowired protected MockMvc mockMvc;
  @MockitoBean SignalingHandler signalingHandler;

  @DynamicPropertySource
  static void configureProperties(DynamicPropertyRegistry registry) {
    registry.add("spring.datasource.url", POSTGRES::getJdbcUrl);
    registry.add("spring.datasource.username", POSTGRES::getUsername);
    registry.add("spring.datasource.password", POSTGRES::getPassword);
    registry.add("spring.data.redis.host", REDIS::getHost);
    registry.add("spring.data.redis.port", () -> REDIS.getMappedPort(6379));
  }

  protected User buildUser(String email, Role role) {
    return User.builder()
        .email(email)
        .role(role)
        .provider(AuthProvider.LOCAL)
        .createdAt(Instant.now())
        .build();
  }
}
