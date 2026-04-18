package com.example.musicplayerbackend.controller;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1")
public class HealthController implements HealthApi {
    @Override
    public ResponseEntity<Void> healthCheck() {
        return ResponseEntity.ok().build();
    }
}
