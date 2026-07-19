package com.example.musicplayerbackend.data;

import static org.assertj.core.api.Assertions.assertThat;

import com.example.musicplayerbackend.domain.ContentType;
import com.example.musicplayerbackend.domain.Song;
import com.example.musicplayerbackend.domain.SongLyrics;
import java.util.UUID;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

class SongLyricsRepositoryTest extends BaseRepositoryTest {

  @Autowired SongRepository songRepository;

  @Autowired SongLyricsRepository songLyricsRepository;

  @AfterEach
  void tearDown() {
    songLyricsRepository.deleteAll();
    songRepository.deleteAll();
  }

  @Test
  void shouldPersistOneLyricsRecordUsingTheSongId() {
    Song song =
        songRepository.save(
            Song.builder()
                .name("Song")
                .songType(ContentType.STREAMABLE)
                .fileHash(UUID.randomUUID().toString())
                .build());

    SongLyrics saved =
        songLyricsRepository.save(
            SongLyrics.builder().song(song).lyrics("[00:00] lyrics").build());

    assertThat(saved.getSongId()).isEqualTo(song.getId());
    assertThat(songLyricsRepository.findById(song.getId()))
        .get()
        .extracting(SongLyrics::getLyrics)
        .isEqualTo("[00:00] lyrics");
  }

  @Test
  void shouldDeleteLyricsWhenTheSongIsDeleted() {
    Song song =
        songRepository.save(
            Song.builder()
                .name("Song")
                .songType(ContentType.STREAMABLE)
                .fileHash(UUID.randomUUID().toString())
                .build());
    songLyricsRepository.save(SongLyrics.builder().song(song).lyrics("lyrics").build());

    songRepository.delete(song);
    songRepository.flush();

    assertThat(songLyricsRepository.findById(song.getId())).isEmpty();
  }
}
