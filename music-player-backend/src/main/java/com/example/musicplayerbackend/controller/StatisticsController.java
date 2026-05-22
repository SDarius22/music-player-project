package com.example.musicplayerbackend.controller;

import com.example.musicplayerbackend.domain.ChunkStatDto;
import com.example.musicplayerbackend.domain.User;
import com.example.musicplayerbackend.service.StatisticsService;
import java.util.List;
import java.util.Objects;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@Slf4j
@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class StatisticsController implements StatisticsApi {

  private final StatisticsService statisticsService;

  @Override
  public ResponseEntity<List<ChunkStatDto>> getStatistics() {
    return ResponseEntity.ok(statisticsService.getAll());
  }

  @Override
  public ResponseEntity<Void> submitStatistic(ChunkStatDto chunkStatDto) {
    User user =
        (User)
            Objects.requireNonNull(SecurityContextHolder.getContext().getAuthentication())
                .getPrincipal();
    statisticsService.record(chunkStatDto, user.getId());
    return ResponseEntity.status(HttpStatus.CREATED).build();
  }
}
