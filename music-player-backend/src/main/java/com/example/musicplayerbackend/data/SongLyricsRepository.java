package com.example.musicplayerbackend.data;

import com.example.musicplayerbackend.domain.SongLyrics;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface SongLyricsRepository extends JpaRepository<SongLyrics, Long> {}
