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
                .autoPlay(true)
                .autoPlayRecommendationsPage(2L)
                .build();

        UserPlaybackState saved = playbackStateRepository.save(state);

        assertThat(saved.getUserId()).isEqualTo(user.getId());
        assertThat(saved.getPositionSeconds()).isEqualTo(5L);
        assertThat(saved.getShuffle()).isTrue();
        assertThat(saved.getRepeat()).isFalse();
        assertThat(saved.getAutoPlay()).isTrue();
        assertThat(saved.getAutoPlayRecommendationsPage()).isEqualTo(2L);
    }

    @Test
    void shouldReturnPlaybackState() {
        playbackStateRepository.save(UserPlaybackState.builder()
                .userId(user.getId())
                .positionSeconds(123L)
                .shuffle(false)
                .repeat(true)
                .autoPlay(true)
                .autoPlayRecommendationsPage(5L)
                .build());

        var found = playbackStateRepository.findById(user.getId());

        assertThat(found).isPresent();
        assertThat(found.get().getPositionSeconds()).isEqualTo(123L);
        assertThat(found.get().getRepeat()).isTrue();
        assertThat(found.get().getAutoPlay()).isTrue();
        assertThat(found.get().getAutoPlayRecommendationsPage()).isEqualTo(5L);
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
                .userId(user.getId()).positionSeconds(1L).shuffle(false).repeat(false)
                .autoPlay(false).autoPlayRecommendationsPage(0L).build());

        playbackStateRepository.save(UserPlaybackState.builder()
                .userId(user.getId()).positionSeconds(99L).shuffle(true).repeat(true)
                .autoPlay(true).autoPlayRecommendationsPage(4L).build());

        var found = playbackStateRepository.findById(user.getId());

        assertThat(found).isPresent();
        assertThat(found.get().getPositionSeconds()).isEqualTo(99L);
        assertThat(found.get().getShuffle()).isTrue();
        assertThat(found.get().getAutoPlay()).isTrue();
        assertThat(found.get().getAutoPlayRecommendationsPage()).isEqualTo(4L);
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
        assertThat(saved.getAutoPlay()).isFalse();
        assertThat(saved.getAutoPlayRecommendationsPage()).isEqualTo(0L);
    }
}
