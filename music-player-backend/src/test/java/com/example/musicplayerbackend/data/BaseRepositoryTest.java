package com.example.musicplayerbackend.data;

import com.example.musicplayerbackend.components.SignalingHandler;
import com.example.musicplayerbackend.domain.AuthProvider;
import com.example.musicplayerbackend.domain.Role;
import com.example.musicplayerbackend.domain.User;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.containers.PostgreSQLContainer;

import java.time.Instant;

/**
 * Base class for all repository-level integration tests.
 * Containers are started once per JVM via static initializer — no port changes between test classes.
 * Each subclass is responsible for cleaning up test data in {@code @AfterEach}.
 */
@SpringBootTest(
        webEnvironment = SpringBootTest.WebEnvironment.NONE,
        properties = {"MAIL_HOST=localhost", "MAIL_USER=test@example.com", "MAIL_PASSWORD=test"}
)
public abstract class BaseRepositoryTest {

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

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", POSTGRES::getJdbcUrl);
        registry.add("spring.datasource.username", POSTGRES::getUsername);
        registry.add("spring.datasource.password", POSTGRES::getPassword);
        registry.add("spring.data.redis.host", REDIS::getHost);
        registry.add("spring.data.redis.port", () -> REDIS.getMappedPort(6379));
    }

    @MockitoBean
    SignalingHandler signalingHandler;

    protected User buildUser(String email) {
        return User.builder()
                .email(email)
                .role(Role.USER)
                .provider(AuthProvider.LOCAL)
                .createdAt(Instant.now())
                .build();
    }
}
