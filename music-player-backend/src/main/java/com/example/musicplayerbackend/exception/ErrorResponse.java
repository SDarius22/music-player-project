package com.example.musicplayerbackend.exception;

import java.time.Instant;

public record ErrorResponse(
    int status, String error, String message, Instant timestamp, String path) {}
