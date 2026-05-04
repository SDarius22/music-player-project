package com.example.musicplayerbackend.data;

import com.example.musicplayerbackend.domain.User;
import com.example.musicplayerbackend.domain.UserPlaybackState;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import static org.assertj.core.api.Assertions.assertThat;

class UserPlaybackStateRepositoryTest extends BaseRepositoryTest {

    @Autowired
    UserPlaybackStateRepository playbackStateRepository;

    @Autowired
    UserRepository userRepository;

    private User user;

    @BeforeEach
    void setUp() {
        user = userRepository.save(buildUser("playback@example.com"));
    }

    @AfterEach
    void tearDown() {
        playbackStateRepository.deleteAll();
        userRepository.deleteAll();
    }

    @Test
    void shouldPersistPlaybackStateWithUserIdAsPk() {
        UserPlaybackState state = UserPlaybackState.builder()
                .userId(user.getId())
                .positionSeconds(5L)
                .shuffle(true)
                .repeat(false)
                .build();

        UserPlaybackState saved = playbackStateRepository.save(state);

        assertThat(saved.getUserId()).isEqualTo(user.getId());
        assertThat(saved.getPositionSeconds()).isEqualTo(5L);
        assertThat(saved.getShuffle()).isTrue();
        assertThat(saved.getRepeat()).isFalse();
    }

    @Test
    void shouldReturnPlaybackState() {
        playbackStateRepository.save(UserPlaybackState.builder()
                .userId(user.getId())
                .positionSeconds(123L)
                .shuffle(false)
                .repeat(true)
                .build());

        var found = playbackStateRepository.findById(user.getId());

        assertThat(found).isPresent();
        assertThat(found.get().getPositionSeconds()).isEqualTo(123L);
        assertThat(found.get().getRepeat()).isTrue();
    }

    @Test
    void shouldReturnEmptyWhenNoPlaybackStateForUser() {
        User other = userRepository.save(buildUser("nostate@example.com"));

        var found = playbackStateRepository.findById(other.getId());

        assertThat(found).isEmpty();
    }

    @Test
    void shouldOverwritePlaybackStateWhenSavedTwiceWithSameUserId() {
        playbackStateRepository.save(UserPlaybackState.builder()
                .userId(user.getId()).positionSeconds(1L).shuffle(false).repeat(false).build());

        playbackStateRepository.save(UserPlaybackState.builder()
                .userId(user.getId()).positionSeconds(99L).shuffle(true).repeat(true).build());

        var found = playbackStateRepository.findById(user.getId());

        assertThat(found).isPresent();
        assertThat(found.get().getPositionSeconds()).isEqualTo(99L);
        assertThat(found.get().getShuffle()).isTrue();
    }

    @Test
    void shouldApplyDefaultsWhenFieldsNotSet() {
        UserPlaybackState state = UserPlaybackState.builder()
                .userId(user.getId())
                .build();

        UserPlaybackState saved = playbackStateRepository.save(state);

        assertThat(saved.getPositionSeconds()).isEqualTo(0L);
        assertThat(saved.getShuffle()).isFalse();
        assertThat(saved.getRepeat()).isFalse();
    }
}
