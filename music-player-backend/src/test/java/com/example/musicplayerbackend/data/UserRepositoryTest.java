package com.example.musicplayerbackend.data;

import com.example.musicplayerbackend.domain.User;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import static org.assertj.core.api.Assertions.assertThat;

class UserRepositoryTest extends BaseRepositoryTest {

    @Autowired
    UserRepository userRepository;

    @AfterEach
    void tearDown() {
        userRepository.deleteAll();
    }

    @Test
    void shouldGenerateIdAndPersistUser() {
        User saved = userRepository.save(buildUser("a@example.com"));

        assertThat(saved.getId()).isNotNull().isPositive();
        assertThat(saved.getEmail()).isEqualTo("a@example.com");
    }

    @Test
    void shouldReturnUserWhenEmailExists() {
        userRepository.save(buildUser("find@example.com"));

        var found = userRepository.findByEmail("find@example.com");

        assertThat(found).isPresent();
        assertThat(found.get().getEmail()).isEqualTo("find@example.com");
    }

    @Test
    void shouldReturnEmptyWhenEmailNotFound() {
        var found = userRepository.findByEmail("nobody@example.com");

        assertThat(found).isEmpty();
    }

    @Test
    void shouldReturnUserById() {
        User saved = userRepository.save(buildUser("byid@example.com"));

        var found = userRepository.findById(saved.getId());

        assertThat(found).isPresent();
        assertThat(found.get().getEmail()).isEqualTo("byid@example.com");
    }

    @Test
    void shouldRemoveUserWhenDeleted() {
        User saved = userRepository.save(buildUser("delete@example.com"));
        userRepository.delete(saved);

        assertThat(userRepository.findByEmail("delete@example.com")).isEmpty();
    }
}
