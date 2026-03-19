package com.example.musicplayerbackend.data;

import com.example.musicplayerbackend.domain.UserPlaybackState;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface UserPlaybackStateRepository extends JpaRepository<UserPlaybackState, Long> {
}
